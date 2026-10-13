-- ═══════════════════════════════════════════════════════════════════════════
--  初始迁移 · 前置片段
--  用途：必须在 Prisma 生成的 gin_trgm_ops 索引之前执行
--  说明：pg_trgm 是 PostgreSQL 的 trusted extension，数据库 owner 即可创建，
--        不需要超级用户权限。
--  依赖方：FR-5.5 关键词搜索、AI 助手 search_work_items 工具（§16.3）
-- ═══════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('ADMIN', 'MEMBER');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'DISABLED');

-- CreateEnum
CREATE TYPE "ThemeMode" AS ENUM ('LIGHT', 'DARK', 'SYSTEM');

-- CreateEnum
CREATE TYPE "ViewType" AS ENUM ('DASHBOARD', 'LIST', 'BOARD', 'CALENDAR');

-- CreateEnum
CREATE TYPE "WorkItemPriority" AS ENUM ('URGENT', 'HIGH', 'MEDIUM', 'LOW');

-- CreateEnum
CREATE TYPE "WorkItemRelationType" AS ENUM ('RELATED', 'BLOCKS', 'BLOCKED_BY');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('ASSIGNED', 'MENTIONED', 'COMMENTED', 'STATUS_CHANGED', 'DUE_SOON', 'OVERDUE', 'SYSTEM');

-- CreateEnum
CREATE TYPE "ChangeSource" AS ENUM ('MANUAL', 'ASSISTANT', 'SYSTEM');

-- CreateEnum
CREATE TYPE "AssistantMessageRole" AS ENUM ('SYSTEM', 'USER', 'ASSISTANT', 'TOOL');

-- CreateEnum
CREATE TYPE "AssistantActionStatus" AS ENUM ('PENDING', 'CONFIRMED', 'REJECTED', 'EXECUTED', 'FAILED', 'UNDONE', 'EXPIRED');

-- CreateEnum
CREATE TYPE "AssistantRiskLevel" AS ENUM ('READ', 'WRITE');

-- CreateEnum
CREATE TYPE "AssistantAutoExecute" AS ENUM ('ALWAYS_CONFIRM', 'LOW_RISK_AUTO');

-- CreateEnum
CREATE TYPE "AssistantPrivacyMode" AS ENUM ('FULL', 'TITLE_ONLY');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "username" VARCHAR(50) NOT NULL,
    "email" VARCHAR(120),
    "password_hash" VARCHAR(100) NOT NULL,
    "nickname" VARCHAR(50) NOT NULL,
    "avatar_url" VARCHAR(500),
    "role" "UserRole" NOT NULL DEFAULT 'MEMBER',
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "failed_attempts" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ(3),
    "last_login_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_preferences" (
    "user_id" UUID NOT NULL,
    "theme" "ThemeMode" NOT NULL DEFAULT 'SYSTEM',
    "default_view" "ViewType" NOT NULL DEFAULT 'DASHBOARD',
    "page_size" INTEGER NOT NULL DEFAULT 20,
    "notify_config" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "user_preferences_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" VARCHAR(128) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "ip" VARCHAR(64),
    "user_agent" VARCHAR(300),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "color" VARCHAR(20) NOT NULL DEFAULT '#1677ff',
    "sort" INTEGER NOT NULL DEFAULT 0,
    "description" VARCHAR(300),
    "owner_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tags" (
    "id" UUID NOT NULL,
    "name" VARCHAR(30) NOT NULL,
    "color" VARCHAR(20) NOT NULL DEFAULT '#1677ff',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "tags_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_item_statuses" (
    "id" UUID NOT NULL,
    "name" VARCHAR(30) NOT NULL,
    "code" VARCHAR(30) NOT NULL,
    "color" VARCHAR(20) NOT NULL DEFAULT '#1677ff',
    "sort" INTEGER NOT NULL DEFAULT 0,
    "is_final" BOOLEAN NOT NULL DEFAULT false,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "allow_transitions" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "work_item_statuses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dictionaries" (
    "id" UUID NOT NULL,
    "category" VARCHAR(30) NOT NULL,
    "key" VARCHAR(50) NOT NULL,
    "value" VARCHAR(100) NOT NULL,
    "sort" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "extra" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "dictionaries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "saved_views" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "view_type" "ViewType" NOT NULL DEFAULT 'LIST',
    "query" JSONB NOT NULL,
    "sort" INTEGER NOT NULL DEFAULT 0,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "saved_views_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_items" (
    "id" UUID NOT NULL,
    "code" VARCHAR(30) NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "type" VARCHAR(30) NOT NULL DEFAULT 'task',
    "priority" "WorkItemPriority" NOT NULL DEFAULT 'MEDIUM',
    "status_id" UUID NOT NULL,
    "category_id" UUID,
    "creator_id" UUID NOT NULL,
    "assignee_id" UUID NOT NULL,
    "start_at" TIMESTAMPTZ(3),
    "due_at" TIMESTAMPTZ(3),
    "completed_at" TIMESTAMPTZ(3),
    "estimate_hours" DECIMAL(7,2),
    "actual_hours" DECIMAL(7,2) NOT NULL DEFAULT 0,
    "progress" INTEGER NOT NULL DEFAULT 0,
    "source" VARCHAR(50),
    "is_pinned" BOOLEAN NOT NULL DEFAULT false,
    "is_archived" BOOLEAN NOT NULL DEFAULT false,
    "parent_id" UUID,
    "sort_weight" INTEGER NOT NULL DEFAULT 0,
    "recurrence_rule" VARCHAR(200),
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "work_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_item_status_logs" (
    "id" UUID NOT NULL,
    "work_item_id" UUID NOT NULL,
    "from_status_id" UUID,
    "to_status_id" UUID NOT NULL,
    "operator_id" UUID NOT NULL,
    "remark" VARCHAR(500),
    "source" "ChangeSource" NOT NULL DEFAULT 'MANUAL',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_item_status_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_item_watchers" (
    "work_item_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_item_watchers_pkey" PRIMARY KEY ("work_item_id","user_id")
);

-- CreateTable
CREATE TABLE "checklist_items" (
    "id" UUID NOT NULL,
    "work_item_id" UUID NOT NULL,
    "content" VARCHAR(300) NOT NULL,
    "is_done" BOOLEAN NOT NULL DEFAULT false,
    "sort" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "checklist_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_item_tags" (
    "work_item_id" UUID NOT NULL,
    "tag_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_item_tags_pkey" PRIMARY KEY ("work_item_id","tag_id")
);

-- CreateTable
CREATE TABLE "work_item_relations" (
    "id" UUID NOT NULL,
    "from_id" UUID NOT NULL,
    "to_id" UUID NOT NULL,
    "type" "WorkItemRelationType" NOT NULL DEFAULT 'RELATED',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_item_relations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "comments" (
    "id" UUID NOT NULL,
    "work_item_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "parent_id" UUID,
    "content_md" TEXT NOT NULL,
    "content_html" TEXT,
    "mentions" JSONB,
    "source" "ChangeSource" NOT NULL DEFAULT 'MANUAL',
    "edited_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" UUID NOT NULL,
    "work_item_id" UUID,
    "comment_id" UUID,
    "uploader_id" UUID NOT NULL,
    "file_name" VARCHAR(255) NOT NULL,
    "stored_path" VARCHAR(500) NOT NULL,
    "mime_type" VARCHAR(120) NOT NULL,
    "size" INTEGER NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "thumb_path" VARCHAR(500),
    "sha256" VARCHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "content" TEXT,
    "link_type" VARCHAR(30),
    "link_id" UUID,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "read_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "action" VARCHAR(50) NOT NULL,
    "target_type" VARCHAR(30),
    "target_id" UUID,
    "detail" JSONB,
    "ip" VARCHAR(64),
    "user_agent" VARCHAR(300),
    "source" "ChangeSource" NOT NULL DEFAULT 'MANUAL',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_conversations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "pinned_context" JSONB,
    "message_count" INTEGER NOT NULL DEFAULT 0,
    "last_message_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "assistant_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_messages" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "role" "AssistantMessageRole" NOT NULL,
    "content" TEXT,
    "tool_calls" JSONB,
    "tool_call_id" VARCHAR(64),
    "model" VARCHAR(60),
    "tokens_in" INTEGER,
    "tokens_out" INTEGER,
    "latency_ms" INTEGER,
    "finish_reason" VARCHAR(30),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "assistant_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_actions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "conversation_id" UUID,
    "message_id" UUID,
    "tool_name" VARCHAR(50) NOT NULL,
    "arguments" JSONB NOT NULL,
    "risk_level" "AssistantRiskLevel" NOT NULL DEFAULT 'WRITE',
    "status" "AssistantActionStatus" NOT NULL DEFAULT 'PENDING',
    "before_snapshot" JSONB,
    "after_snapshot" JSONB,
    "result" JSONB,
    "error" TEXT,
    "affected_count" INTEGER NOT NULL DEFAULT 1,
    "expires_at" TIMESTAMPTZ(3),
    "confirmed_at" TIMESTAMPTZ(3),
    "executed_at" TIMESTAMPTZ(3),
    "undone_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "assistant_actions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_usage_daily" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "stat_date" DATE NOT NULL,
    "requests" INTEGER NOT NULL DEFAULT 0,
    "tokens_in" INTEGER NOT NULL DEFAULT 0,
    "tokens_out" INTEGER NOT NULL DEFAULT 0,
    "failed_requests" INTEGER NOT NULL DEFAULT 0,
    "cost_cents" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "assistant_usage_daily_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_settings" (
    "user_id" UUID NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "auto_execute_level" "AssistantAutoExecute" NOT NULL DEFAULT 'ALWAYS_CONFIRM',
    "allowed_tools" JSONB,
    "system_prompt_extra" TEXT,
    "privacy_mode" "AssistantPrivacyMode" NOT NULL DEFAULT 'FULL',
    "daily_token_budget" INTEGER,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "assistant_settings_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_tokens_user_id_revoked_at_idx" ON "refresh_tokens"("user_id", "revoked_at");

-- CreateIndex
CREATE INDEX "refresh_tokens_expires_at_idx" ON "refresh_tokens"("expires_at");

-- CreateIndex
CREATE INDEX "categories_deleted_at_sort_idx" ON "categories"("deleted_at", "sort");

-- CreateIndex
CREATE INDEX "tags_deleted_at_idx" ON "tags"("deleted_at");

-- CreateIndex
CREATE UNIQUE INDEX "work_item_statuses_code_key" ON "work_item_statuses"("code");

-- CreateIndex
CREATE INDEX "work_item_statuses_sort_idx" ON "work_item_statuses"("sort");

-- CreateIndex
CREATE UNIQUE INDEX "dictionaries_category_key_key" ON "dictionaries"("category", "key");

-- CreateIndex
CREATE UNIQUE INDEX "saved_views_user_id_name_key" ON "saved_views"("user_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "work_items_code_key" ON "work_items"("code");

-- CreateIndex
CREATE INDEX "work_items_deleted_at_is_archived_status_id_due_at_idx" ON "work_items"("deleted_at", "is_archived", "status_id", "due_at");

-- CreateIndex
CREATE INDEX "work_items_assignee_id_deleted_at_idx" ON "work_items"("assignee_id", "deleted_at");

-- CreateIndex
CREATE INDEX "work_items_creator_id_deleted_at_idx" ON "work_items"("creator_id", "deleted_at");

-- CreateIndex
CREATE INDEX "work_items_category_id_deleted_at_idx" ON "work_items"("category_id", "deleted_at");

-- CreateIndex
CREATE INDEX "work_items_priority_due_at_idx" ON "work_items"("priority", "due_at");

-- CreateIndex
CREATE INDEX "work_items_parent_id_idx" ON "work_items"("parent_id");

-- CreateIndex
CREATE INDEX "work_items_deleted_at_updated_at_idx" ON "work_items"("deleted_at", "updated_at");

-- CreateIndex
CREATE INDEX "work_items_title_idx" ON "work_items" USING GIN ("title" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "work_items_description_idx" ON "work_items" USING GIN ("description" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "work_items_code_idx" ON "work_items" USING GIN ("code" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "work_item_status_logs_work_item_id_created_at_idx" ON "work_item_status_logs"("work_item_id", "created_at");

-- CreateIndex
CREATE INDEX "work_item_status_logs_operator_id_created_at_idx" ON "work_item_status_logs"("operator_id", "created_at");

-- CreateIndex
CREATE INDEX "work_item_watchers_user_id_idx" ON "work_item_watchers"("user_id");

-- CreateIndex
CREATE INDEX "checklist_items_work_item_id_sort_idx" ON "checklist_items"("work_item_id", "sort");

-- CreateIndex
CREATE INDEX "work_item_tags_tag_id_idx" ON "work_item_tags"("tag_id");

-- CreateIndex
CREATE INDEX "work_item_relations_to_id_idx" ON "work_item_relations"("to_id");

-- CreateIndex
CREATE UNIQUE INDEX "work_item_relations_from_id_to_id_type_key" ON "work_item_relations"("from_id", "to_id", "type");

-- CreateIndex
CREATE INDEX "comments_work_item_id_created_at_idx" ON "comments"("work_item_id", "created_at");

-- CreateIndex
CREATE INDEX "comments_user_id_created_at_idx" ON "comments"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "comments_parent_id_idx" ON "comments"("parent_id");

-- CreateIndex
CREATE INDEX "comments_content_md_idx" ON "comments" USING GIN ("content_md" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "attachments_work_item_id_idx" ON "attachments"("work_item_id");

-- CreateIndex
CREATE INDEX "attachments_comment_id_idx" ON "attachments"("comment_id");

-- CreateIndex
CREATE INDEX "attachments_uploader_id_created_at_idx" ON "attachments"("uploader_id", "created_at");

-- CreateIndex
CREATE INDEX "attachments_created_at_idx" ON "attachments"("created_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_is_read_created_at_idx" ON "notifications"("user_id", "is_read", "created_at");

-- CreateIndex
CREATE INDEX "notifications_created_at_idx" ON "notifications"("created_at");

-- CreateIndex
CREATE INDEX "audit_logs_user_id_created_at_idx" ON "audit_logs"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_target_type_target_id_idx" ON "audit_logs"("target_type", "target_id");

-- CreateIndex
CREATE INDEX "audit_logs_action_created_at_idx" ON "audit_logs"("action", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_source_created_at_idx" ON "audit_logs"("source", "created_at");

-- CreateIndex
CREATE INDEX "assistant_conversations_user_id_last_message_at_idx" ON "assistant_conversations"("user_id", "last_message_at");

-- CreateIndex
CREATE INDEX "assistant_messages_conversation_id_created_at_idx" ON "assistant_messages"("conversation_id", "created_at");

-- CreateIndex
CREATE INDEX "assistant_actions_status_user_id_idx" ON "assistant_actions"("status", "user_id");

-- CreateIndex
CREATE INDEX "assistant_actions_conversation_id_created_at_idx" ON "assistant_actions"("conversation_id", "created_at");

-- CreateIndex
CREATE INDEX "assistant_actions_expires_at_idx" ON "assistant_actions"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "assistant_usage_daily_user_id_stat_date_key" ON "assistant_usage_daily"("user_id", "stat_date");

-- AddForeignKey
ALTER TABLE "user_preferences" ADD CONSTRAINT "user_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "saved_views" ADD CONSTRAINT "saved_views_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_items" ADD CONSTRAINT "work_items_status_id_fkey" FOREIGN KEY ("status_id") REFERENCES "work_item_statuses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_items" ADD CONSTRAINT "work_items_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_items" ADD CONSTRAINT "work_items_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_items" ADD CONSTRAINT "work_items_assignee_id_fkey" FOREIGN KEY ("assignee_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_items" ADD CONSTRAINT "work_items_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "work_items"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "work_item_status_logs" ADD CONSTRAINT "work_item_status_logs_work_item_id_fkey" FOREIGN KEY ("work_item_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_status_logs" ADD CONSTRAINT "work_item_status_logs_from_status_id_fkey" FOREIGN KEY ("from_status_id") REFERENCES "work_item_statuses"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_status_logs" ADD CONSTRAINT "work_item_status_logs_to_status_id_fkey" FOREIGN KEY ("to_status_id") REFERENCES "work_item_statuses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_status_logs" ADD CONSTRAINT "work_item_status_logs_operator_id_fkey" FOREIGN KEY ("operator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_watchers" ADD CONSTRAINT "work_item_watchers_work_item_id_fkey" FOREIGN KEY ("work_item_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_watchers" ADD CONSTRAINT "work_item_watchers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "checklist_items" ADD CONSTRAINT "checklist_items_work_item_id_fkey" FOREIGN KEY ("work_item_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_tags" ADD CONSTRAINT "work_item_tags_work_item_id_fkey" FOREIGN KEY ("work_item_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_tags" ADD CONSTRAINT "work_item_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_relations" ADD CONSTRAINT "work_item_relations_from_id_fkey" FOREIGN KEY ("from_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_item_relations" ADD CONSTRAINT "work_item_relations_to_id_fkey" FOREIGN KEY ("to_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_work_item_id_fkey" FOREIGN KEY ("work_item_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "comments"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_work_item_id_fkey" FOREIGN KEY ("work_item_id") REFERENCES "work_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_uploader_id_fkey" FOREIGN KEY ("uploader_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_conversations" ADD CONSTRAINT "assistant_conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_messages" ADD CONSTRAINT "assistant_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "assistant_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_actions" ADD CONSTRAINT "assistant_actions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_actions" ADD CONSTRAINT "assistant_actions_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "assistant_conversations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_actions" ADD CONSTRAINT "assistant_actions_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "assistant_messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_usage_daily" ADD CONSTRAINT "assistant_usage_daily_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_settings" ADD CONSTRAINT "assistant_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

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
