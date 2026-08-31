# 软件台账（主控登记处）

> **本文件是三台 Mac 软件的唯一事实源。Brewfile（core + 机器文件）是它的机器投影。**
> 分类：① 开发工具 ② 协作通信 ③ 网络安全 ④ 办公文档(含浏览器/媒体) ⑤ 效率系统 ⑥ 内网公司专用
>
> 基线：mini = 2026-08-27 实况；pro13 / pro14 = 2026-08-25 快照（待各机跑 `audit-manual-apps.sh` 核对修正）。
> 图例：✓ = cask/mas 在装 · m = 手动装 · — = 未装。状态：在用 / 待退役 / 待清理 / 决策中 / 停更。

## 使用规范

**新装软件**：① 台账加一行（类别/token/装哪几台/状态）→ ② 对应 `Brewfile.core`（三机通用）或 `Brewfile.<hostname>` 加条目 → ③ mini 上 `chezmoi apply` + push，辅机 `chezmoi update && brew bundle install`。
**退役软件**：① 台账状态改「待退役」→ ② Brewfile 删条目（或移入历史记录注释区）→ ③ 各机 `brew uninstall`。
**定期校验**：每台跑 `mac-env-sync/scripts/audit-manual-apps.sh`，对照本台账——台账说的和磁盘装的是否一致。
**辅机拉取已存在的手动装 app**：先 `brew install --cask --adopt <token>` 收编，再 `brew bundle`（否则撞 already-an-App 报错）。pkg 型 cask（tailscale-app / microsoft-teams）要在交互终端跑，或用 plan 文档附录的 SUDO_ASKPASS 弹窗法。

---

## ① 开发工具（编辑器 / 终端 / 数据库 / API / AI / 云客户端）

| App | 来源 | token/id | mini | p13 | p14 | 状态 | 备注 |
|---|---|---|:--:|:--:|:--:|---|---|
| Ghostty | cask-p14 | `ghostty` | m | m | ✓ | 在用 | mini/p13 待收编（主力终端） |
| VS Code Insiders | 手动 | `visual-studio-code@insiders` | m | m | m | 在用 | 主力编辑器；待收编（自更频繁，adopt 需版本吻合） |
| iTerm2 | 手动 | `iterm2` | m | m | m | 在用 | |
| Sublime Text | core | `sublime-text` | ✓ | m | m | 在用 | 2026-08-27 收编 mini；p13/p14 拉取时先 adopt |
| ~~IntelliJ IDEA (Ult)~~ | 手动 | `intellij-idea` | 已卸 | — | m | **已退役** | 2026-08-27 mini 卸载（含 JetBrains 配置清理）；p14 仍装；重装走 cask |
| Termius | core | `termius` | ✓ | — | — | 在用 | 账号云同步 |
| ~~DBeaver CE~~ | p13 | `dbeaver-community` | 已卸 | m | — | **已退役(mini)** | 2026-08-27 mini 卸载（数据库统一用 DBX）；p13 仍装 |
| DBX | core | `dbx` | ✓ | m | m | 在用 | |
| Postman | mini+p13 | `postman` | ✓ | m | — | 在用 | |
| Proxyman | mini+p13 | `proxyman` | ✓ | m | — | 在用 | |
| ~~Sequel Ace~~ | 已撤 | `sequel-ace` | 已清 | ⚠ | — | **已退役** | 2026-08-27 全线退役（数据库统一 DBX）；mini receipt+数据已清；p13 receipt 残留待该机清 |
| Sourcetree | 手动 | `sourcetree` | m | m | — | 在用 | |
| WindTerm | 手动 | — | — | — | m | | p14 |
| Navicat Premium | 手动 | — | — | — | m | | p14 |
| Claude | 手动 | `claude` | m | — | — | 在用 | 待收编 |
| ChatGPT | 手动 | `chatgpt` | m | m | — | 在用 | |
| Codex (OpenAI) | 手动 | — | — | — | m | | p14（≠ mini 的 Codex++） |
| Codex++ | 手动 | 无 cask | m | — | — | | ⚠ cask `codex` 是别的产品 |
| Cherry Studio | 手动 | — | — | — | m | | p14 |
| LM Studio | 手动 | — | — | — | m | | p14（machines.toml 提 mini 曾有，当前快照无） |
| Ollama | 手动 | — | — | — | m | | p14 |
| itermAI | 手动 | — | — | — | m | | p14 |
| 微信开发者工具 | 手动 | `wechatwebdevtools` | m | m | m | 在用 | |
| oss-browser (阿里云) | 手动 | `oss-browser` | m | m | m* | 在用 | p14 是 oss-browser2（新版名） |
| cosbrowser (腾讯云) | 手动 | 无 cask | m | m | — | 保留 | |
| Cyberduck | 已卸 | `cyberduck` | 已清 | — | — | **已退役** | 2026-08-31 当日装当日卸：堡垒机交互链不支持（Transmit 回滚），通用场景无增量价值，只留 Transmit 一个 |
| Transmit | 手动 | `transmit` | m | m | — | 在用 | ⚠ **不入 brew：勿在任何 Brewfile 声明**（bundle 会与手动版冲突/覆盖）。2026-08-31 定案手动安装 5.11.6；二进制无 Panic 签名与公证（TeamIdentifier=not set，Gatekeeper rejected，审计事实）；堡垒机交互链（密码+MFA+选服务器）依赖它；连接数据在 ~/Library/Application Support/Transmit |
| SecureFX | 手动 | 无 cask | m | m | — | 保留 | VanDyke 官网渠道 |
| marktext | 手动 | cask 已移除 | m | m | — | 停更 | 项目停更 |
| Warp | cask-p14 | `warp` | m | — | ✓ | 待退役 | mini 2026-08-27 决定不转（主力 Ghostty） |
| Applite | mini | `applite` | ✓ | — | — | 在用 | 2026-08-27 brew GUI（免费/开源/官方 cask）；先试 Cork 因 €25 付费换掉；Cakebrew(停更) 前身已删 |
| ~~Antigravity Tools~~ | 已撤 | `antigravity-tools` | 已清 | — | — | **已退役** | 2026-08-27 卸载（app 早已不在磁盘）；tap lbjlaq/antigravity-manager 已 untap；台账勘误：p14 从未装过（前版误标） |
| github-copilot-for-xcode | cask-p14 | 同名 | — | — | ✓ | 在用 | |
| miniforge | cask-p14 | 同名 | — | — | ✓ | 在用 | |
| Xcode | 手动 | — | — | — | m | 在用 | 重件，不入 cask |
| Final Cut Pro | 手动 | — | — | — | m | 在用 | p14，重件 |

## ② 协作通信（IM / 会议 / 邮件）

| App | 来源 | token/id | mini | p13 | p14 | 状态 | 备注 |
|---|---|---|:--:|:--:|:--:|---|---|
| 微信 | 手动 | `wechat` | m | m | m | 在用 | 待收编 |
| 企业微信 | 手动 | `wechatwork` | m | — | — | 在用 | ⚠ 勿用 wecom（token 不存在） |
| Lark (国际版) | 手动 | `lark` | m | — | — | 在用 | ⚠ feishu 是国内飞书，别装错 |
| 钉钉 | 手动 | `dingtalk` | m | m | m | 在用 | 三台都有，待收编进 core |
| 腾讯会议 | 手动 | `tencent-meeting` | m | m | — | 在用 | |
| Microsoft Teams | mini+p13 | `microsoft-teams` | ✓ | m | — | 在用 | pkg 型（要 sudo） |

## ③ 网络安全（VPN / 代理 / 远控 / 防火墙）

| App | 来源 | token/id | mini | p13 | p14 | 状态 | 备注 |
|---|---|---|:--:|:--:|:--:|---|---|
| Tailscale | core | `tailscale-app` | ✓ | — | — | 在用 | pkg 型；组网骨干；p13/p14 需要时单独装+登录 |
| Clash Verge Rev | 手动 | `clash-verge-rev` | m | m | m | 在用 | ⚠ 原版 clash-verge 已死档 |
| ClashX Pro | 手动 | 无 cask | m | m | m | 待清理 | mini 建议退役（与 Clash Verge 重复） |
| ngrok | core | 同名 | ✓ | ✓ | — | 在用 | CLI 型 |
| ~~LuLu~~ | 已撤 | `lulu` | 已清 | ⚠ | — | **已退役** | 2026-08-27 弃用（出站防火墙）；mini receipt + /Library/Objective-See(root 属主, 2022 遗留) 已清；p13 receipt 待清 |
| AnyDesk | 手动 | `anydesk` | m | m | m | 在用 | |
| ToDesk | 手动 | 无 cask | m | m | — | 在用 | |
| AweSun (向日葵) | 手动 | — | — | m | — | | p13 |
| Windows App | mas | 1295203466 | ✓ | ✓ | — | 在用 | MRD 新版（远控） |
| Microsoft Remote Desktop | 手动 | — | m | m | — | 待清理 | 旧版，Windows App 已替代，建议删 |

## ④ 办公文档（浏览器 / 文档 / 知识 / 媒体）

| App | 来源 | token/id | mini | p13 | p14 | 状态 | 备注 |
|---|---|---|:--:|:--:|:--:|---|---|
| Google Chrome | core | `google-chrome` | ✓ | m | m | 在用 | 2026-08-27 收编 mini |
| Microsoft Edge | core | `microsoft-edge` | ✓ | m | m | 在用 | 同上 |
| 115Browser | 手动 | — | — | — | m | | p14 |
| WPS Office | 手动 | `wpsoffice-cn`? | m | m | — | 在用 | 装时核对 cn/intl 账号体系 |
| Keynote / Pages / Numbers | mas | 409183694 等 | ✓ | ✓ | ✓ | 在用 | |
| XMind | 手动 | `xmind` | m | — | — | 在用 | |
| Obsidian | 手动 | `obsidian` | m | m | m | 在用 | |
| MarkViewer | 手动 | — | — | m | — | | p13 |
| 网易云音乐 | 手动 | `neteasemusic` | m | m | m | 在用 | ⚠ 不是 netease-cloud-music |
| 哔哩哔哩 | 手动 | — | — | — | m | | p14 |
| IINA | 手动 | — | — | — | m | | p14 |
| 夸克 | 手动 | — | — | — | m | | p14 |
| Motrix | 手动 | — | — | — | m | | p14 |
| Downie 4 | 手动 | — | — | — | m | | p14 |
| 剪映 (VideoFusion) | 手动 | — | — | — | m | | p14 |
| iMovie / GarageBand | mas (mini) | 408981434 / 682658836 | ✓ | — | m | 在用 | mas 声明在 MacMini；p14 为自带 |
| EdgeView | 手动 | — | — | — | m | | p14 图片查看 |

## ⑤ 效率系统（启动器 / 截图 / 剪贴板 / 窗口 / 清理 / 传输）

| App | 来源 | token/id | mini | p13 | p14 | 状态 | 备注 |
|---|---|---|:--:|:--:|:--:|---|---|
| Alfred 5 | 手动 | `alfred` | m | m | m | 在用 | |
| Rectangle | 手动 | `rectangle` | m | m | — | 在用 | |
| Shottr | 手动 | `shottr` | m | m | — | 在用 | |
| Kap | 手动 | `kap` | m | m | — | 在用 | |
| Keka | core | `keka` | ✓ | m | m | 在用 | 2026-08-31 mini 收编：1.2.16→1.6.7（adopt 版本错位用 reinstall 解决）；p13/p14 拉取时 `brew install --cask --adopt keka` 再 bundle |
| CopyQ | core | `copyq` | ✓ | ✓ | — | 在用 | p14 未装（core 声明，bundle 时会装上） |
| SwitchHosts | 手动 | `switchhosts` | m | m | m | 在用 | |
| ColorSnapper2 | 手动 | `colorsnapper` | m | m | — | 保留 | ⚠ token 无 2 |
| DaisyDisk | 手动 | `daisydisk` | m | m | m | 在用 | |
| CleanMyMac X | 手动 | `cleanmymac` | m | m | — | 在用 | p14 是 CleanMyMac_5（不同形态） |
| Magic Battery | mas | id 待查 | ✓ | ✓ | — | 在用 | 未登记 Brewfile，待补 mas 条目 |
| Tencent Lemon | 手动 | — | — | m | — | | p13 清理工具 |
| Monitoring Helper | 手动 | 无 cask | m | m | — | 保留 | core 已有 macmon |
| Stats | core | `stats` | ✓ | ✓ | — | 在用 | 2026-08-31 新装收编 core：菜单栏实时系统监控（内存/压力/swap/进程排行，兼 CPU/GPU/网络）；免费开源 exelban/stats；终端侧监控已有 macmon(core)；mini/p13 brew 直装（无 adopt 步骤），p14 拉取时会装上 |
| Filo | 手动 | 无（⚠ filo=filomail） | m | m | — | 保留 | cask filo 是别的产品，勿装 |
| Caesium | 手动 | 无 cask | m | m | — | 保留 | |
| 罗技 Options+ | 手动（官网） | 无 cask | m | m | — | 保留 | |
| BaiduNetdisk | 手动 | — | — | — | m | | p14 |
| Folx GO+ | 手动 | — | — | — | m | | p14 |
| DeepL | 手动 | — | — | — | m | | p14 |
| Adobe Activation/Downloader | 手动 | — | — | — | m | | p14 工具 |
| Longshot / OmniRecorder | 手动 | — | — | — | m | | p14 录制 |

## ⑥ 内网公司专用（手动装，不入 brew 体系）

| App | mini | p13 | p14 | 备注 |
|---|:--:|:--:|:--:|---|
| EasyConnect（深信服） | m | m | m | 内网 VPN |
| PrinterClient | m | m | — | 打印客户端 |
| 微信支付商户平台证书工具 | m | m | — | |
| 淘宝开发者工具 | m | m | — | |
| Apifox 企业版 | m | m | — | ⚠ cask apifox 是标准版 |
| CC Switch | ✓(receipt) | ✓(receipt) | ✓(receipt) | 特例：tap 限定 Monterey，已装机器保留 3.9+；tap 需 trust |
| Open Island | ⚠ | m* | m | ⚠ mini receipt 在但 app 不在；cask 已从源消失 |

---

## 特殊事项

- **tap trust**（2026-08-27 发现）：Homebrew 新版要求 trust 第三方 tap，未 trust 时 `brew list --versions` 等命令报错。精确信任清单见 plan 文档。
- **receipt 残留三件**（mini）：lulu / sequel-ace / antigravity-tools——装回 or 清除，待决策（plan 文档 1.3）。
- **mas 遗漏**：Magic Battery 未登记（id 待查后补进对应 Brewfile）。
- **Claude Code URL Handler**（~/Applications）：Claude Code 生成物，不管理。
- **Safari / iTermBrowserPlugin**：系统自带 / iTerm2 组件，不管理。
