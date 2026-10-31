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
  let verdict: { passed: boolean; reason: string };
  try {
    const image = await blobToDataUrl(photo.data);
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST", headers: { "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "gpt-4.1-mini", temperature: 0, response_format: { type: "json_object" }, messages: [
        { role: "system", content: "You judge whether a submitted photo satisfies a scavenger-hunt mission. Return JSON only: {passed:boolean,reason:string}. Be concise and reject if the evidence is unclear." },
        { role: "user", content: [{ type: "text", text: `Mission: ${context.data.mission}` }, { type: "image_url", image_url: { url: image } }] },
      ] }),
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => null);
      console.error(JSON.stringify({
        event: "openai_http_error",
        status: response.status,
        type: errorBody?.error?.type ?? null,
        code: errorBody?.error?.code ?? null,
      }));
      return json({ error: "judge_unavailable" }, 503);
    }
    const payload = await response.json();
    const parsed = JSON.parse(payload.choices?.[0]?.message?.content ?? "");
    if (typeof parsed.passed !== "boolean" || typeof parsed.reason !== "string") throw new Error("invalid judge response");
    verdict = parsed;
  } catch (error) {
    console.error(JSON.stringify({
      event: "openai_request_error",
      type: error instanceof Error ? error.name : "unknown",
    }));
    return json({ error: "judge_unavailable" }, 503);
  }
  const recorded = await admin.rpc("_record_judgement", { p_room_id: roomId, p_checkpoint_id: checkpointId, p_user_id: user.id, p_photo_path: photoPath, p_passed: verdict.passed, p_reason: verdict.reason });
  if (recorded.error) return recorded.error.message.startsWith("MQ:") ? mq(recorded.error.message) : json({ error: "judge_unavailable" }, 503);
  return json(recorded.data);
});

async function blobToDataUrl(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  return `data:${blob.type || "image/jpeg"};base64,${encodeBase64(bytes)}`;
}
