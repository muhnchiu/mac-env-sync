# radar-reports

软件雷达日报存档。每日由 app-radar 抓取数据后，对照 `../manuals/app-inventory.md` 台账分析生成。

## 文件命名

`YYYY-MM-DD.md` — 与原始抓取数据同日期。

## 数据源

- 抓取：Hacker News / Product Hunt / 少数派 / 小众软件
- 台账对照：`../manuals/app-inventory.md`
- cask 验证：`brew search --cask <name>` / `brew info --cask <name>`

## 原始数据

原始抓取文件在 `~/.local/state/app-radar/YYYY-MM-DD.md`，本目录只存分析日报。
