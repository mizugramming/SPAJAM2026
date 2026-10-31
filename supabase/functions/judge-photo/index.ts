import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encodeBase64 } from "jsr:@std/encoding/base64";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const mq = (message: string) => json({ error: message }, 400);

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authorization = request.headers.get("Authorization");
  if (!authorization) return mq("MQ:permission");
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user } } = await caller.auth.getUser();
  if (!user) return mq("MQ:permission");
  let input: { room_id?: string; checkpoint_id?: string; photo_path?: string };
  try { input = await request.json(); } catch { return mq("MQ:notFound"); }
  const roomId = input.room_id; const checkpointId = input.checkpoint_id; const photoPath = input.photo_path;
  if (!roomId || !checkpointId || !photoPath || !photoPath.startsWith(`${roomId}/${user.id}/`)) return mq("MQ:permission");
  const admin = createClient(url, serviceKey);
  const context = await admin.rpc("_judge_context", { p_room_id: roomId, p_checkpoint_id: checkpointId, p_user_id: user.id });
  if (context.error) return context.error.message.startsWith("MQ:") ? mq(context.error.message) : json({ error: "judge_unavailable" }, 503);
  const photo = await caller.storage.from("photos").download(photoPath);
  if (photo.error) return mq("MQ:notFound");
  const photoBytes = new Uint8Array(await photo.data.arrayBuffer());
  const dimensions = jpegDimensions(photoBytes);
  if (dimensions === null || Math.min(dimensions.width, dimensions.height) < 480) {
    const reason = dimensions === null
      ? "画像サイズを確認できません。撮り直してください。"
      : "画像が小さすぎます。近づいて撮り直してください。";
    const recorded = await admin.rpc("_record_judgement", { p_room_id: roomId, p_checkpoint_id: checkpointId, p_user_id: user.id, p_photo_path: photoPath, p_passed: false, p_reason: reason });
    if (recorded.error) return recorded.error.message.startsWith("MQ:") ? mq(recorded.error.message) : json({ error: "judge_unavailable" }, 503);
    return json(recorded.data);
  }
  let verdict: { passed: boolean; reason: string; evidence?: string };
  try {
    const image = dataUrlFromBytes(photoBytes, photo.data.type);
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST", headers: { "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "gpt-4.1-mini", temperature: 0, response_format: { type: "json_object" }, messages: [
        { role: "system", content: "あなたはスタンプラリー写真の厳格な視覚判定者です。実際の画像だけを確認し、ミッション文から対象を推測してはいけません。JSONのみを返してください: {passed:boolean,reason:string,evidence:string}。passed=trueにできるのは、画像にミッションの正確な対象が直接かつ明確に写っている場合だけです。無地、単色、無関係、不鮮明、遮蔽、または確信できない画像は必ず不合格にしてください。合格時のevidenceには見えている具体的な対象を、不合格時のreasonには不足している視覚的根拠を書いてください。reasonとevidenceは必ず自然な日本語のみで返してください。" },
        { role: "user", content: [{ type: "text", text: `Mission: ${context.data.mission}` }, { type: "image_url", image_url: { url: image, detail: "high" } }] },
      ] }),
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => null);
      console.error(JSON.stringify({
        event: "openai_http_error",
        status: response.status,
        type: errorBody?.error?.type ?? null,
        code: errorBody?.error?.code ?? null,
        message: safeErrorMessage(errorBody?.error?.message),
      }));
      return json({ error: "judge_unavailable" }, 503);
    }
    const payload = await response.json();
    const parsed = JSON.parse(payload.choices?.[0]?.message?.content ?? "");
    if (typeof parsed.passed !== "boolean" || typeof parsed.reason !== "string" || (parsed.passed && (typeof parsed.evidence !== "string" || parsed.evidence.trim() === ""))) throw new Error("invalid judge response");
    verdict = { ...parsed, reason: japaneseReason(parsed.reason, parsed.passed) };
  } catch (error) {
    console.error(JSON.stringify({
      event: "openai_request_error",
      type: error instanceof Error ? error.name : "unknown",
      message: safeErrorMessage(error instanceof Error ? error.message : null),
    }));
    return json({ error: "judge_unavailable" }, 503);
  }
  const recorded = await admin.rpc("_record_judgement", { p_room_id: roomId, p_checkpoint_id: checkpointId, p_user_id: user.id, p_photo_path: photoPath, p_passed: verdict.passed, p_reason: verdict.reason });
  if (recorded.error) return recorded.error.message.startsWith("MQ:") ? mq(recorded.error.message) : json({ error: "judge_unavailable" }, 503);
  return json(recorded.data);
});

function dataUrlFromBytes(bytes: Uint8Array, mimeType: string): string {
  return `data:${mimeType || "image/jpeg"};base64,${encodeBase64(bytes)}`;
}

function safeErrorMessage(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return value
      .replace(/sk-[A-Za-z0-9_-]+/g, "[redacted-openai-key]")
      .replace(/Bearer\s+\S+/gi, "Bearer [redacted]")
      .slice(0, 500);
}

function japaneseReason(reason: string, passed: boolean): string {
  return /[A-Za-z]/.test(reason)
      ? passed ? "写真にミッションの対象が確認できました。" : "写真に必要な対象を確認できませんでした。"
      : reason;
}

function jpegDimensions(bytes: Uint8Array): { width: number; height: number } | null {
  if (bytes.length < 10 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;
  for (let offset = 2; offset + 8 < bytes.length;) {
    if (bytes[offset] !== 0xff) { offset += 1; continue; }
    while (offset < bytes.length && bytes[offset] === 0xff) offset += 1;
    const marker = bytes[offset++];
    if (marker === 0xd8 || marker === 0xd9 || marker === 0x01) continue;
    if (offset + 1 >= bytes.length) return null;
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
      return { height: (bytes[offset + 3] << 8) | bytes[offset + 4], width: (bytes[offset + 5] << 8) | bytes[offset + 6] };
    }
    offset += length;
  }
  return null;
}
