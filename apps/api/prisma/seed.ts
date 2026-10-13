/**
 * 种子数据 —— 系统运行所必需的参考数据
 *
 * 只写“没有它系统就跑不起来”的数据：
 *   · 状态字典（FR-3.1）—— work_items.status_id 是必填外键，没有状态就建不了工作项
 *   · 系统字典（FR-11.1 / FR-11.2）—— 工作项类型、来源、系统参数默认值
 *   · 几个常用标签与默认分类（FR-6）
 *
 * 刻意不在这里创建管理员账号：密码哈希方案属于 M0 的 auth 模块决策
 * （bcrypt / argon2），且 FR-1.10 要求“空库首次访问引导创建管理员”。
 * 用错误哈希建出来的账号无法登录，反而会误导人。
 *
 * 执行：npm run db:seed
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/** 状态字典：默认流转见需求文档 §3 FR-3 状态流转图 */
const STATUSES = [
  { code: 'TODO', name: '待办', color: '#8c8c8c', sort: 10, isFinal: false, isDefault: true, allowTransitions: ['DOING', 'BLOCKED', 'CANCELLED'] },
  { code: 'DOING', name: '进行中', color: '#1677ff', sort: 20, isFinal: false, isDefault: false, allowTransitions: ['TODO', 'BLOCKED', 'REVIEW', 'DONE', 'CANCELLED'] },
  { code: 'BLOCKED', name: '阻塞', color: '#fa541c', sort: 30, isFinal: false, isDefault: false, allowTransitions: ['TODO', 'DOING', 'CANCELLED'] },
  { code: 'REVIEW', name: '待验收', color: '#722ed1', sort: 40, isFinal: false, isDefault: false, allowTransitions: ['DOING', 'DONE', 'CANCELLED'] },
  { code: 'DONE', name: '已完成', color: '#52c41a', sort: 50, isFinal: true, isDefault: false, allowTransitions: ['DOING', 'REVIEW'] },
  { code: 'CANCELLED', name: '已取消', color: '#bfbfbf', sort: 60, isFinal: true, isDefault: false, allowTransitions: ['TODO', 'DOING'] },
];

const DICTIONARIES = [
  // 工作项类型（FR-2.2 / §3.1 type 字段）
  { category: 'work_item_type', key: 'task', value: '任务', sort: 10 },
  { category: 'work_item_type', key: 'feature', value: '需求', sort: 20 },
  { category: 'work_item_type', key: 'bug', value: '缺陷', sort: 30 },
  { category: 'work_item_type', key: 'meeting', value: '会议', sort: 40 },
  { category: 'work_item_type', key: 'study', value: '学习', sort: 50 },
  { category: 'work_item_type', key: 'other', value: '其他', sort: 60 },
  // 来源（§3.1 source 字段）
  { category: 'work_item_source', key: 'self', value: '自己规划', sort: 10 },
  { category: 'work_item_source', key: 'leader', value: '领导交办', sort: 20 },
  { category: 'work_item_source', key: 'feedback', value: '线上反馈', sort: 30 },
  { category: 'work_item_source', key: 'meeting', value: '会议决议', sort: 40 },
  // 系统参数（FR-11.2）
  { category: 'system', key: 'register_enabled', value: 'false', sort: 10 },
  { category: 'system', key: 'upload_max_size_mb', value: '10', sort: 20 },
  { category: 'system', key: 'attachment_ext_whitelist', value: 'jpg,jpeg,png,gif,webp,pdf,zip,docx,xlsx,txt,md', sort: 30 },
  { category: 'system', key: 'trash_retention_days', value: '30', sort: 40 },
  { category: 'system', key: 'assistant_enabled', value: 'true', sort: 50 },
  { category: 'system', key: 'assistant_action_ttl_minutes', value: '10', sort: 60 },
];

const TAGS = [
  { name: '紧急', color: '#f5222d' },
  { name: '待跟进', color: '#faad14' },
  { name: '已交付', color: '#52c41a' },
];

async function main() {
  for (const s of STATUSES) {
    await prisma.workItemStatus.upsert({
      where: { code: s.code },
      create: { ...s },
      update: {
        name: s.name,
        color: s.color,
        sort: s.sort,
        isFinal: s.isFinal,
        isDefault: s.isDefault,
        allowTransitions: s.allowTransitions,
      },
    });
  }
  console.log(`✓ 状态字典 ${STATUSES.length} 条`);

  for (const d of DICTIONARIES) {
    await prisma.dictionary.upsert({
      where: { category_key: { category: d.category, key: d.key } },
      create: { ...d },
      update: { value: d.value, sort: d.sort },
    });
  }
  console.log(`✓ 系统字典 ${DICTIONARIES.length} 条`);

  for (const t of TAGS) {
    const exists = await prisma.tag.findFirst({ where: { name: t.name, deletedAt: null } });
    if (!exists) await prisma.tag.create({ data: { ...t } });
  }
  console.log(`✓ 标签 ${TAGS.length} 条`);

  const category = await prisma.category.findFirst({ where: { name: '日常工作', deletedAt: null } });
  if (!category) {
    await prisma.category.create({
      data: { name: '日常工作', color: '#1677ff', sort: 10, description: '默认分类' },
    });
  }
  console.log('✓ 默认分类「日常工作」');
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
