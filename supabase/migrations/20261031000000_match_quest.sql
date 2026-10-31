create extension if not exists pgcrypto;

create table public.courses (
  id text primary key, name text not null, start_qr text not null,
  goal_qr text not null, time_limit_seconds integer not null check (time_limit_seconds > 0)
);
create table public.checkpoints (
  id text primary key, course_id text not null references public.courses(id) on delete cascade,
  name text not null, floor text not null, qr text not null, mission text not null,
  points integer not null check (points >= 0), required boolean not null, sort_order integer not null,
  unique (course_id, qr), unique (course_id, sort_order)
);
create table public.rooms (
  id uuid primary key default gen_random_uuid(), code text not null check (code ~ '^[0-9]{6}$'),
  course_id text not null references public.courses(id), owner_id uuid not null references auth.users(id),
  status text not null default 'waiting' check (status in ('waiting', 'running', 'finished')),
  created_at timestamptz not null default now(), started_at timestamptz, ends_at timestamptz, finished_at timestamptz,
  check ((status = 'waiting' and started_at is null and ends_at is null and finished_at is null)
      or (status = 'running' and started_at is not null and ends_at is not null and finished_at is null)
      or (status = 'finished' and finished_at is not null))
);
create unique index rooms_active_code_key on public.rooms(code) where status <> 'finished';
create table public.participants (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id), display_name text not null check (btrim(display_name) <> ''),
  joined_at timestamptz not null default now(), start_scanned_at timestamptz, goal_at timestamptz,
  primary key (room_id, user_id)
);
create table public.submissions (
  id uuid primary key default gen_random_uuid(), room_id uuid not null references public.rooms(id) on delete cascade,
  participant_id uuid not null, checkpoint_id text not null references public.checkpoints(id), photo_path text not null,
  submitted_at timestamptz not null default now(), status text not null check (status in ('pending','passed','rejected')),
  reason text, judged_at timestamptz,
  foreign key (room_id, participant_id) references public.participants(room_id, user_id),
  check ((status = 'pending' and judged_at is null) or (status in ('passed','rejected') and judged_at is not null))
);
create table public.checkpoint_clears (
  room_id uuid not null, participant_id uuid not null, checkpoint_id text not null references public.checkpoints(id),
  points integer not null check (points >= 0), cleared_at timestamptz not null default now(),
  submission_id uuid not null references public.submissions(id),
  unique (room_id, participant_id, checkpoint_id),
  foreign key (room_id, participant_id) references public.participants(room_id, user_id)
);
create index participants_room_id_idx on public.participants(room_id);
create index submissions_room_id_idx on public.submissions(room_id);
create index checkpoint_clears_room_id_idx on public.checkpoint_clears(room_id);

alter table public.courses enable row level security;
alter table public.checkpoints enable row level security;
alter table public.rooms enable row level security;
alter table public.participants enable row level security;
alter table public.submissions enable row level security;
alter table public.checkpoint_clears enable row level security;

create or replace function public.is_room_viewer(p_room_id uuid, p_user_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from rooms where id = p_room_id and owner_id = p_user_id)
      or exists(select 1 from participants where room_id = p_room_id and user_id = p_user_id)
$$;
grant execute on function public.is_room_viewer(uuid, uuid) to authenticated;

create policy "authenticated read courses" on public.courses for select to authenticated using (true);
create policy "authenticated read checkpoints" on public.checkpoints for select to authenticated using (true);
create policy "room viewers read rooms" on public.rooms for select to authenticated using (public.is_room_viewer(id));
create policy "room viewers read participants" on public.participants for select to authenticated using (public.is_room_viewer(room_id));
create policy "room viewers read clears" on public.checkpoint_clears for select to authenticated using (public.is_room_viewer(room_id));
create policy "owners read all submissions" on public.submissions for select to authenticated using (exists(select 1 from rooms where id = room_id and owner_id = auth.uid()));
create policy "participants read own submissions" on public.submissions for select to authenticated using (participant_id = auth.uid() and public.is_room_viewer(room_id));

create or replace function public.require_user() returns uuid language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); begin if v_user is null then raise exception 'MQ:permission'; end if; return v_user; end $$;
create or replace function public.expire_rooms() returns void language sql security definer set search_path = public as $$
  update rooms set status = 'finished', finished_at = ends_at
  where status = 'running' and ends_at <= now()
$$;

create or replace function public.create_room(p_course_id text) returns json language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); v_room rooms%rowtype; v_code text; begin
  if not exists(select 1 from courses where id = p_course_id) then raise exception 'MQ:notFound'; end if;
  perform expire_rooms();
  loop
    v_code := lpad((floor(random() * 900000)::integer + 100000)::text, 6, '0');
    begin insert into rooms(code, course_id, owner_id) values(v_code, p_course_id, v_user) returning * into v_room; exit;
    exception when unique_violation then end;
  end loop;
  return to_json(v_room);
end $$;
create or replace function public.start_room(p_room_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); v_seconds integer; begin
  select c.time_limit_seconds into v_seconds from rooms r join courses c on c.id=r.course_id where r.id=p_room_id and r.owner_id=v_user;
  if not found then if exists(select 1 from rooms where id=p_room_id) then raise exception 'MQ:permission'; else raise exception 'MQ:notFound'; end if; end if;
  update rooms set status='running', started_at=now(), ends_at=now() + make_interval(secs => v_seconds) where id=p_room_id and status='waiting';
  if not found then raise exception 'MQ:roomNotWaiting'; end if;
end $$;
create or replace function public.finish_room(p_room_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); begin
  if not exists(select 1 from rooms where id=p_room_id) then raise exception 'MQ:notFound'; end if;
  if not exists(select 1 from rooms where id=p_room_id and owner_id=v_user) then raise exception 'MQ:permission'; end if;
  update rooms set status='finished', finished_at=case when ends_at is not null and ends_at < now() then ends_at else now() end where id=p_room_id and status <> 'finished';
end $$;
create or replace function public.find_room_by_code(p_code text) returns json language plpgsql security definer set search_path = public as $$
declare v_room rooms%rowtype; begin perform require_user(); perform expire_rooms(); select * into v_room from rooms where code=btrim(p_code) order by created_at desc limit 1; if not found then raise exception 'MQ:notFound'; end if; return to_json(v_room); end $$;
create or replace function public.join_room(p_room_id uuid, p_display_name text) returns json language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); v_participant participants%rowtype; begin
  select * into v_participant from participants where room_id=p_room_id and user_id=v_user; if found then return to_json(v_participant); end if;
  perform expire_rooms(); if not exists(select 1 from rooms where id=p_room_id) then raise exception 'MQ:notFound'; end if;
  if exists(select 1 from rooms where id=p_room_id and owner_id=v_user) then raise exception 'MQ:permission'; end if;
  if not exists(select 1 from rooms where id=p_room_id and status='waiting') then raise exception 'MQ:roomNotWaiting'; end if;
  if btrim(p_display_name)='' then raise exception 'MQ:permission'; end if;
  insert into participants(room_id,user_id,display_name) values(p_room_id,v_user,btrim(p_display_name)) returning * into v_participant; return to_json(v_participant);
end $$;
create or replace function public.scan_start(p_room_id uuid, p_qr text) returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); begin
  if not exists(select 1 from participants where room_id=p_room_id and user_id=v_user) then raise exception 'MQ:permission'; end if;
  perform expire_rooms(); if not exists(select 1 from rooms where id=p_room_id) then raise exception 'MQ:notFound'; end if;
  if exists(select 1 from rooms where id=p_room_id and status='finished') then raise exception 'MQ:roomNotRunning'; end if;
  if not exists(select 1 from rooms r join courses c on c.id=r.course_id where r.id=p_room_id and c.start_qr=p_qr) then raise exception 'MQ:wrongQr'; end if;
  update participants set start_scanned_at=now() where room_id=p_room_id and user_id=v_user and start_scanned_at is null;
end $$;
create or replace function public.scan_checkpoint(p_room_id uuid, p_qr text) returns text language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); v_checkpoint text; v_status text; begin
  select status into v_status from rooms where id=p_room_id; if not found then raise exception 'MQ:notFound'; end if;
  if not exists(select 1 from participants where room_id=p_room_id and user_id=v_user) then raise exception 'MQ:permission'; end if;
  if v_status='waiting' then raise exception 'MQ:roomNotRunning'; end if; perform expire_rooms();
  if exists(select 1 from rooms where id=p_room_id and status='finished') then if v_status='running' then raise exception 'MQ:timeUp'; else raise exception 'MQ:roomNotRunning'; end if; end if;
  if not exists(select 1 from participants where room_id=p_room_id and user_id=v_user and start_scanned_at is not null) then raise exception 'MQ:startNotScanned'; end if;
  if exists(select 1 from participants where room_id=p_room_id and user_id=v_user and goal_at is not null) then raise exception 'MQ:alreadyFinished'; end if;
  select cp.id into v_checkpoint from rooms r join checkpoints cp on cp.course_id=r.course_id where r.id=p_room_id and cp.qr=p_qr; if not found then raise exception 'MQ:wrongQr'; end if; return v_checkpoint;
end $$;
create or replace function public.scan_goal(p_room_id uuid, p_qr text) returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := require_user(); v_status text; begin
  select status into v_status from rooms where id=p_room_id; if not found then raise exception 'MQ:notFound'; end if;
  if not exists(select 1 from participants where room_id=p_room_id and user_id=v_user) then raise exception 'MQ:permission'; end if;
  if v_status='waiting' then raise exception 'MQ:roomNotRunning'; end if; perform expire_rooms();
  if exists(select 1 from rooms where id=p_room_id and status='finished') then if v_status='running' then raise exception 'MQ:timeUp'; else raise exception 'MQ:roomNotRunning'; end if; end if;
  if not exists(select 1 from participants where room_id=p_room_id and user_id=v_user and start_scanned_at is not null) then raise exception 'MQ:startNotScanned'; end if;
  if exists(select 1 from participants where room_id=p_room_id and user_id=v_user and goal_at is not null) then raise exception 'MQ:alreadyFinished'; end if;
  if not exists(select 1 from rooms r join courses c on c.id=r.course_id where r.id=p_room_id and c.goal_qr=p_qr) then raise exception 'MQ:wrongQr'; end if;
  if exists(select 1 from checkpoints cp join rooms r on r.course_id=cp.course_id where r.id=p_room_id and cp.required and not exists(select 1 from checkpoint_clears cc where cc.room_id=p_room_id and cc.participant_id=v_user and cc.checkpoint_id=cp.id)) then raise exception 'MQ:requiredNotCleared'; end if;
  update participants set goal_at=now() where room_id=p_room_id and user_id=v_user;
end $$;

-- Edge Function only: validates and writes at database time, never callable by clients.
create or replace function public._judge_context(p_room_id uuid, p_checkpoint_id text, p_user_id uuid) returns json language plpgsql security definer set search_path = public as $$
declare v_status text; v_mission text; begin
  select status into v_status from rooms where id=p_room_id; if not found then raise exception 'MQ:notFound'; end if;
  if not exists(select 1 from participants where room_id=p_room_id and user_id=p_user_id) then raise exception 'MQ:permission'; end if;
  if v_status='waiting' then raise exception 'MQ:roomNotRunning'; end if; perform expire_rooms();
  if exists(select 1 from rooms where id=p_room_id and status='finished') then if v_status='running' then raise exception 'MQ:timeUp'; else raise exception 'MQ:roomNotRunning'; end if; end if;
  if not exists(select 1 from participants where room_id=p_room_id and user_id=p_user_id and start_scanned_at is not null) then raise exception 'MQ:startNotScanned'; end if;
  if exists(select 1 from participants where room_id=p_room_id and user_id=p_user_id and goal_at is not null) then raise exception 'MQ:alreadyFinished'; end if;
  select cp.mission into v_mission from rooms r join checkpoints cp on cp.course_id=r.course_id where r.id=p_room_id and cp.id=p_checkpoint_id; if not found then raise exception 'MQ:notFound'; end if;
  return json_build_object('mission', v_mission);
end $$;
create or replace function public._record_judgement(p_room_id uuid, p_checkpoint_id text, p_user_id uuid, p_photo_path text, p_passed boolean, p_reason text) returns json language plpgsql security definer set search_path = public as $$
declare v_context json; v_submission uuid; v_points integer; v_inserted integer; begin
  v_context := _judge_context(p_room_id,p_checkpoint_id,p_user_id);
  insert into submissions(room_id,participant_id,checkpoint_id,photo_path,status,reason,judged_at) values(p_room_id,p_user_id,p_checkpoint_id,p_photo_path,case when p_passed then 'passed' else 'rejected' end,p_reason,now()) returning id into v_submission;
  if not p_passed then return json_build_object('outcome','rejected','reason',p_reason,'points_awarded',0,'already_cleared',false); end if;
  select points into v_points from checkpoints where id=p_checkpoint_id;
  insert into checkpoint_clears(room_id,participant_id,checkpoint_id,points,cleared_at,submission_id) values(p_room_id,p_user_id,p_checkpoint_id,v_points,now(),v_submission) on conflict (room_id,participant_id,checkpoint_id) do nothing;
  get diagnostics v_inserted = row_count;
  return json_build_object('outcome','passed','reason',p_reason,'points_awarded',case when v_inserted=1 then v_points else 0 end,'already_cleared',v_inserted=0);
end $$;

revoke all on function public._judge_context(uuid,text,uuid) from public, anon, authenticated;
revoke all on function public._record_judgement(uuid,text,uuid,text,boolean,text) from public, anon, authenticated;
grant execute on function public._judge_context(uuid,text,uuid), public._record_judgement(uuid,text,uuid,text,boolean,text) to service_role;
revoke all on function public.require_user(), public.expire_rooms() from public, anon, authenticated;
revoke all on function public.is_room_viewer(uuid,uuid) from public, anon;
grant execute on function public.is_room_viewer(uuid,uuid) to authenticated;
revoke all on function public.create_room(text), public.start_room(uuid), public.finish_room(uuid), public.find_room_by_code(text), public.join_room(uuid,text), public.scan_start(uuid,text), public.scan_checkpoint(uuid,text), public.scan_goal(uuid,text) from public, anon;
grant execute on function public.create_room(text), public.start_room(uuid), public.finish_room(uuid), public.find_room_by_code(text), public.join_room(uuid,text), public.scan_start(uuid,text), public.scan_checkpoint(uuid,text), public.scan_goal(uuid,text) to authenticated;

alter publication supabase_realtime add table public.rooms, public.participants, public.submissions, public.checkpoint_clears;
insert into storage.buckets (id, name, public) values ('photos','photos',false) on conflict (id) do update set public=false;
create policy "participants upload own room photos" on storage.objects for insert to authenticated with check (bucket_id='photos' and (storage.foldername(name))[2]=auth.uid()::text and exists(select 1 from public.participants where room_id=(storage.foldername(name))[1]::uuid and user_id=auth.uid()));
create policy "room viewers read photos" on storage.objects for select to authenticated using (bucket_id='photos' and public.is_room_viewer((storage.foldername(name))[1]::uuid));
