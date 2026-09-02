# radar-reports

AI 模型/工具雷达与软件雷达日报存档。

## 目录结构

- `app/` — 软件雷达日报（每日 08:30，app-radar）
- `ai/` — AI 模型与工具雷达日报（每日 08:45，ai-radar）

## 文件命名

`YYYY-MM-DD.md` — 与原始抓取数据同日期。

## 软件雷达（app/）

- 抓取：Hacker News / Product Hunt / 少数派 / 小众软件
- 台账对照：`../manuals/app-inventory.md`
- cask 验证：`brew search --cask <name>` / `brew info --cask <name>`
- 原始数据在 `~/.local/state/app-radar/YYYY-MM-DD.md`，本目录只存分析日报

## AI 雷达（ai/）

- 抓取：HuggingFace Papers / GitHub AI 新仓库 / HN AI 讨论 / OpenRouter 模型列表 / TechCrunch AI / arXiv LLM
- 聚焦：新模型发布、免费模型、价格/能力变化、AI 工具生态
- 原始数据在 `~/.local/state/ai-radar/YYYY-MM-DD.md`，本目录只存分析日报
