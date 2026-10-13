# 白狼 · 日常工作待办管理系统

一个自用的、可多人的日常工作记录与待办跟踪 Web 应用 —— 把每天"做了什么、做到哪一步、留下什么材料"沉淀成可检索、可统计的数据；并内置 AI 助手，用一句话就能查、能改、能记。

## 技术栈

| 层 | 选型 |
| --- | --- |
| 前端 | Vue 3 + Vite + TypeScript + ant-design-vue（亮/暗色） |
| 后端 | Node.js + NestJS + Prisma |
| 数据库 | PostgreSQL 17 |
| AI 助手 | DeepSeek 官方 API（OpenAI 兼容协议，适配层可切换） |
| 部署 | Docker Compose + Nginx，腾讯云轻量应用服务器 |

## 目录结构

```
├─ docs/                 # 需求、设计与环境文档（先读这里）
├─ apps/
│  ├─ api/               # NestJS 后端 + Prisma 数据层
│  └─ web/               # Vue 3 前端（M0 阶段建立）
├─ deploy/               # Docker Compose、Nginx、备份脚本（M4 阶段建立）
└─ .local/               # 本机凭据与缓存（已 gitignore，不入库）
```

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [01-需求规格说明书](docs/01-需求规格说明书.md) | 12 个功能模块、120 条需求、数据模型、接口清单、部署方案、里程碑、验收标准 |
| [02-本机数据库环境](docs/02-本机数据库环境.md) | 本机 PostgreSQL 安装信息、账号、运维与备份命令、中文 Windows 的 psql 编码坑 |
| [03-数据模型说明](docs/03-数据模型说明.md) | 23 张表 / 13 个枚举的设计说明、数据库级约束、常用命令、回归测试 |

## 后端数据层快速开始

```powershell
cd apps\api
Copy-Item .env.example .env     # 填入本机 DATABASE_URL
npm install
npm run migrate:deploy          # 应用迁移（开发期改用 npm run migrate:dev）
npm run db:seed                 # 写入状态字典等种子数据
npm run db:studio               # 可选：可视化查看数据
```

数据库结构完整性回归测试（事务内执行，不留残留数据）：

```powershell
psql -h 127.0.0.1 -U worklog -d worklog -f apps/api/prisma/sql/99-verify-integrity.sql
```

## 当前进度

- [x] 需求分析与规格说明书（v1.1，含 AI 助手设计）
- [x] 本机 PostgreSQL 环境
- [x] 数据模型落地（Prisma Schema + 迁移 + 种子数据 + 回归测试）
- [ ] M0 基础设施：pnpm workspace、前后端脚手架、登录鉴权
- [ ] M1 核心可用：工作项 CRUD、手动改状态、亮暗色切换
- [ ] M2 协作完善：图文评论、附件、标签筛选、看板
- [ ] M3 统计与通知
- [ ] M4 部署上线
- [ ] M6 AI 助手
