insert into public.courses (id, name, start_qr, goal_qr, time_limit_seconds) values
  ('sample', 'サンプルコース（仮）', 'MQ-START-sample', 'MQ-GOAL-sample', 1800)
on conflict (id) do update set name=excluded.name, start_qr=excluded.start_qr, goal_qr=excluded.goal_qr, time_limit_seconds=excluded.time_limit_seconds;
insert into public.checkpoints (id, course_id, name, floor, qr, mission, points, required, sort_order) values
  ('cp-a','sample','チェックポイントA（仮）','1F','MQ-CP-sample-a','案内板を撮影する',10,true,1),
  ('cp-b','sample','チェックポイントB（仮）','2F','MQ-CP-sample-b','階段の踊り場の窓を撮影する',10,true,2),
  ('cp-free-1','sample','自由ミッション1（仮）','1F','MQ-CP-sample-free-1','赤いものを撮影する',5,false,3)
on conflict (id) do update set course_id=excluded.course_id, name=excluded.name, floor=excluded.floor, qr=excluded.qr, mission=excluded.mission, points=excluded.points, required=excluded.required, sort_order=excluded.sort_order;
