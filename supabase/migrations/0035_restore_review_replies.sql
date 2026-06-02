set search_path = public;

create table if not exists review_replies (
  id              uuid primary key default gen_random_uuid(),
  review_user_id  uuid not null,
  site_id         text not null,
  user_id         uuid not null references auth.users(id) on delete cascade,
  author_name     text check (
    author_name is null or char_length(author_name) <= 80
  ),
  comment         text not null check (
    char_length(comment) between 1 and 500
  ),
  updated_at      timestamptz not null default now(),
  foreign key (review_user_id, site_id)
    references reviews(user_id, site_id) on delete cascade
);

create index if not exists idx_review_replies_target
  on review_replies (site_id, review_user_id);

alter table review_replies enable row level security;

drop policy if exists "review_replies_select_public" on review_replies;
create policy "review_replies_select_public" on review_replies
  for select using (true);

drop policy if exists "review_replies_insert_own" on review_replies;
create policy "review_replies_insert_own" on review_replies
  for insert with check (auth.uid() = user_id);

drop policy if exists "review_replies_update_own" on review_replies;
create policy "review_replies_update_own" on review_replies
  for update using (auth.uid() = user_id);

drop policy if exists "review_replies_delete_own" on review_replies;
create policy "review_replies_delete_own" on review_replies
  for delete using (auth.uid() = user_id);

create or replace function set_review_reply_author_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is not null then
    select coalesce(display_name, '')
      into new.author_name
      from profiles
     where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_review_reply_author_name on review_replies;
create trigger trg_set_review_reply_author_name
  before insert or update on review_replies
  for each row execute function set_review_reply_author_name();
