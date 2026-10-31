create or replace function public._record_judgement(p_room_id uuid, p_checkpoint_id text, p_user_id uuid, p_photo_path text, p_passed boolean, p_reason text) returns json language plpgsql security definer set search_path = public as $$
declare v_submission uuid; v_points integer; v_inserted integer; begin
  perform _judge_context(p_room_id,p_checkpoint_id,p_user_id);
  insert into submissions(room_id,participant_id,checkpoint_id,photo_path,status,reason,judged_at) values(p_room_id,p_user_id,p_checkpoint_id,p_photo_path,case when p_passed then 'passed' else 'rejected' end,p_reason,now()) returning id into v_submission;
  if not p_passed then return json_build_object('outcome','rejected','reason',p_reason,'points_awarded',0,'already_cleared',false); end if;
  select points into v_points from checkpoints where id=p_checkpoint_id;
  insert into checkpoint_clears(room_id,participant_id,checkpoint_id,points,cleared_at,submission_id) values(p_room_id,p_user_id,p_checkpoint_id,v_points,now(),v_submission) on conflict (room_id,participant_id,checkpoint_id) do nothing;
  get diagnostics v_inserted = row_count;
  return json_build_object('outcome','passed','reason',p_reason,'points_awarded',case when v_inserted=1 then v_points else 0 end,'already_cleared',v_inserted=0);
end $$;
