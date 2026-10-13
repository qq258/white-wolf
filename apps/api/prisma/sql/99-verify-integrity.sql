-- ═══════════════════════════════════════════════════════════════════════════
--  数据模型完整性回归测试
--
--  用途：每次改完 schema / 迁移后，在本机库上跑一遍，确认约束与级联仍然生效。
--  执行：
--      psql -h 127.0.0.1 -U worklog -d worklog -f apps/api/prisma/sql/99-verify-integrity.sql
--  前置：已完成 `prisma migrate deploy` + `npm run db:seed`（需要一个 is_default = true 的状态）
--
--  特性：全部在事务内执行，最后 ROLLBACK，**不会在库里留下任何测试数据**。
--  预期：看到 "正向插入全部成功"、级联计数全为 0、6 处约束报错（错误是预期结果）。
-- ═══════════════════════════════════════════════════════════════════════════

begin;

\echo '=== 1) 正向：外键链路全部可插入 ==='
insert into users (id, username, password_hash, nickname, role, status, created_at, updated_at)
values ('11111111-1111-1111-1111-111111111111', 'verify_user', '$2b$10$abcdefghijklmnopqrstuv', 'verify', 'MEMBER', 'ACTIVE', now(), now());

insert into categories (id, name, color, sort, created_at, updated_at)
values ('22222222-2222-2222-2222-222222222222', 'verify_cat', '#1677ff', 1, now(), now());

insert into work_items (id, code, title, priority, status_id, category_id, creator_id, assignee_id, created_at, updated_at)
select '33333333-3333-3333-3333-333333333333', 'W-VERIFY-001', 'verify item', 'MEDIUM', s.id,
       '22222222-2222-2222-2222-222222222222',
       '11111111-1111-1111-1111-111111111111',
       '11111111-1111-1111-1111-111111111111', now(), now()
from work_item_statuses s where s.is_default = true;

insert into work_item_status_logs (id, work_item_id, from_status_id, to_status_id, operator_id, remark, source, created_at)
select '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', null, s.id,
       '11111111-1111-1111-1111-111111111111', 'created', 'MANUAL', now()
from work_item_statuses s where s.is_default = true;

insert into comments (id, work_item_id, user_id, content_md, source, created_at, updated_at)
values ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'verify comment', 'MANUAL', now(), now());

insert into attachments (id, comment_id, uploader_id, file_name, stored_path, mime_type, size, created_at)
values ('66666666-6666-6666-6666-666666666666', '55555555-5555-5555-5555-555555555555',
        '11111111-1111-1111-1111-111111111111', 'verify.png', '2026/10/verify.png', 'image/png', 1234, now());

insert into assistant_conversations (id, user_id, title, created_at, updated_at)
values ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'verify conv', now(), now());

insert into assistant_messages (id, conversation_id, role, content, created_at)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 'USER', 'verify msg', now());

insert into assistant_actions (id, user_id, conversation_id, message_id, tool_name, arguments, risk_level, status, affected_count, created_at, updated_at)
values ('99999999-9999-9999-9999-999999999999', '11111111-1111-1111-1111-111111111111',
        '77777777-7777-7777-7777-777777777777', '88888888-8888-8888-8888-888888888888',
        'change_status', '{"ref":"W-VERIFY-001","status":"DONE"}'::jsonb, 'WRITE', 'PENDING', 1, now(), now());

select '正向插入全部成功' as result;

\echo '=== 2) 级联：删除工作项后，评论/附件/状态日志应归零（FR-4.13）==='
delete from work_items where id = '33333333-3333-3333-3333-333333333333';
select (select count(*) from comments)              as comments_left,
       (select count(*) from attachments)           as attachments_left,
       (select count(*) from work_item_status_logs) as status_logs_left;

\echo '=== 3a) 反向：progress = 150 → 应被 work_items_progress_check 拒绝 ==='
savepoint sp1;
insert into work_items (id, code, title, status_id, creator_id, assignee_id, progress, created_at, updated_at)
select 'aaaaaaaa-0000-0000-0000-000000000001', 'W-VERIFY-BAD1', 'bad progress', s.id,
       '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 150, now(), now()
from work_item_statuses s where s.is_default = true;
rollback to savepoint sp1;

\echo '=== 3b) 反向：附件同时绑定工作项与评论 → 应被 attachments_single_owner_check 拒绝 ==='
savepoint sp2;
insert into attachments (id, work_item_id, comment_id, uploader_id, file_name, stored_path, mime_type, size, created_at)
values ('aaaaaaaa-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
        'bad.png', '2026/10/bad.png', 'image/png', 1, now());
rollback to savepoint sp2;

\echo '=== 3c) 反向：第二个 is_default = true 的状态 → 应被 work_item_statuses_one_default_uidx 拒绝 ==='
savepoint sp3;
insert into work_item_statuses (id, name, code, color, sort, is_final, is_default, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000003', 'X', 'X_DUP_DEFAULT', '#000000', 99, false, true, now(), now());
rollback to savepoint sp3;

\echo '=== 3d) 反向：重复的未删除分类名 → 应被 categories_name_active_uidx 拒绝 ==='
savepoint sp4;
insert into categories (id, name, color, sort, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000004', 'verify_cat', '#000000', 2, now(), now());
rollback to savepoint sp4;

\echo '=== 3e) 反向：引用不存在的状态 → 应被外键拒绝 ==='
savepoint sp5;
insert into work_items (id, code, title, status_id, creator_id, assignee_id, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000005', 'W-VERIFY-BAD2', 'bad fk',
        'deadbeef-dead-beef-dead-beefdeadbeef',
        '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', now(), now());
rollback to savepoint sp5;

\echo '=== 3f) 反向：重复的工作项编号 → 应被 work_items_code_key 拒绝 ==='
savepoint sp6;
insert into work_items (id, code, title, status_id, creator_id, assignee_id, created_at, updated_at)
select 'aaaaaaaa-0000-0000-0000-000000000006', 'W-UNIQ-001', 'uniq a', s.id,
       '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', now(), now()
from work_item_statuses s where s.is_default = true;
insert into work_items (id, code, title, status_id, creator_id, assignee_id, created_at, updated_at)
select 'aaaaaaaa-0000-0000-0000-000000000007', 'W-UNIQ-001', 'uniq b', s.id,
       '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', now(), now()
from work_item_statuses s where s.is_default = true;
rollback to savepoint sp6;

\echo '=== 4) 全部撤销，库内不留测试数据 ==='
rollback;

select (select count(*) from users)      as users_after_rollback,
       (select count(*) from work_items) as work_items_after_rollback,
       (select count(*) from categories where name = 'verify_cat') as verify_cat_left;
