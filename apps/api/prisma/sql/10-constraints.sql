-- ═══════════════════════════════════════════════════════════════════════════
--  初始迁移 · 追加片段
--  用途：Prisma schema 语法无法表达的数据库级约束与索引
--  由初始化脚本追加到 migration.sql 末尾
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) 部分唯一索引：名称唯一只约束“未删除”的行，软删除后可重建同名
--    （FR-6.1 分类、FR-6.2 标签；普通 UNIQUE 做不到这点，因为 NULL 在唯一索引中互不相等）
CREATE UNIQUE INDEX IF NOT EXISTS categories_name_active_uidx
  ON categories (name) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS tags_name_active_uidx
  ON tags (name) WHERE deleted_at IS NULL;

-- 2) 状态字典：全局只允许一个默认状态（FR-3.1）
CREATE UNIQUE INDEX IF NOT EXISTS work_item_statuses_one_default_uidx
  ON work_item_statuses (is_default) WHERE is_default = true;

-- 3) 取值约束：脏数据在数据库层就拦住，不依赖应用层自觉
ALTER TABLE work_items
  ADD CONSTRAINT work_items_progress_check
  CHECK (progress >= 0 AND progress <= 100);

ALTER TABLE work_items
  ADD CONSTRAINT work_items_hours_check
  CHECK ((estimate_hours IS NULL OR estimate_hours >= 0) AND actual_hours >= 0);

-- 附件至多绑定一个宿主；两者都为空 = “已上传但尚未绑定的暂存文件”（FR-4.13）
ALTER TABLE attachments
  ADD CONSTRAINT attachments_single_owner_check
  CHECK (NOT (work_item_id IS NOT NULL AND comment_id IS NOT NULL));
