# 2026-08-27 手动安装 app 收编 brew cask —— 盘点与执行计划

> 状态：⏸ **待逐项确认**（本文是核对底稿，尚未执行任何收编）
> 由来：Tailscale / Termius 手动安装转 cask 后，对 mini 做的全量盘点（2026-08-27）。
> 工具：`scripts/audit-manual-apps.sh`（三台通用，见下）。
> **主控台账**：`docs/manuals/app-inventory.md`（三机软件单一事实源；本文只管"收编执行"，台账管"长期登记"）。

## 快速使用（三台各跑一遍）

```bash
cd ~/workspace/mac-env-sync
./scripts/audit-manual-apps.sh | tee snapshots/audit-$(scutil --get HostName).txt
```

输出四段：A=cask 已接管 / B=App Store / **C=手动安装（主要看这段）** / D=receipt 残留告警。
拿 C 段结果对照本文「二、token 对照表」勾选，再按「四、执行流程」操作。

已知噪音：**pkg 型 cask**（如 `tailscale-app`）装出的 app 会出现在 C 段（cask 无 app 工件可比对），忽略即可；`Safari`、`iTermBrowserPlugin`（iTerm2 组件）、`Claude Code URL Handler`（Claude Code 生成物）同样忽略。

---

## 一、Mini 盘点结果（2026-08-27，/Applications 共 65 项）

| 归类 | 数量 | 说明 |
|---|---|---|
| cask receipt | 11 | 其中 **3 个 app 已不在磁盘**（见 1.3 残留） |
| App Store | 7 | GarageBand / iMovie / Keynote / Numbers / Pages / Windows App / Magic Battery |
| 手动安装 | ~47 | 见 1.1（可转）与 1.2（保持手动） |

### 1.1 可转 cask —— 待勾选（39）

**国际常用（30）**

- [x] Google Chrome · `com.google.Chrome` → `google-chrome`（2026-08-27 mini 已 adopt + core 登记）
- [x] Microsoft Edge · `com.microsoft.edgemac` → `microsoft-edge`（2026-08-27 mini 已 adopt + core 登记）
- [x] Microsoft Teams · `com.microsoft.teams2` → `microsoft-teams`（2026-08-27 mini 已装，**pkg 型**；mini+pro13 登记机器文件）
- [ ] VS Code Insiders · `com.microsoft.VSCodeInsiders` → `visual-studio-code@insiders`（token 带 @）
- [x] Sublime Text · `com.sublimetext.4` → `sublime-text`（2026-08-27 mini 已 adopt + core 登记，三机都有）
- [ ] Claude · `com.anthropic.claudefordesktop` → `claude`
- [ ] ChatGPT · `com.openai.codex` → `chatgpt`
- [ ] iTerm2 · `com.googlecode.iterm2` → `iterm2`
- [ ] Ghostty · `com.mitchellh.ghostty` → `ghostty`（Pro14 文件已声明，注释建议上提 core）
- [~] Warp · `dev.warp.Warp-Stable` → `warp` —— **2026-08-27 决定不转**：已不常用（主力 Ghostty），保持手动装现状；Pro14 Brewfile 里的 `cask "warp"` 声明保留（那台本就是 cask 装的）
- [~] IntelliJ IDEA · `com.jetbrains.intellij`（Ultimate）→ `intellij-idea` —— **2026-08-27 已卸载**（决定不用了，含 JetBrains 配置清理）；p14 上仍装
- [x] DBeaver CE · `org.jkiss.dbeaver.core.product` → `dbeaver-community`（2026-08-27 mini 已 adopt；mini+pro13 登记机器文件。**下载坑见下**）
- [x] Postman · `com.postmanlabs.mac` → `postman`（2026-08-27 mini 已 adopt；mini+pro13 登记机器文件）
- [x] Proxyman · `com.proxyman.NSProxy` → `proxyman`（2026-08-27 同上）
- [ ] Sourcetree · `com.torusknot.SourceTreeNotMAS` → `sourcetree`
- [ ] Transmit · `com.panic.Transmit` → `transmit`（授权在 ~/Library，收编不影响）
- [ ] DaisyDisk · `com.daisydiskapp.DaisyDiskStandAlone` → `daisydisk`
- [ ] Kaleidoscope · `app.kaleidoscope.v4` → `kaleidoscope`（同上）
- [ ] Alfred 5 · `com.runningwithcrayons.Alfred` → `alfred`
- [ ] Rectangle · `com.knollsoft.Rectangle` → `rectangle`
- [ ] Shottr · `cc.ffitch.shottr` → `shottr`
- [ ] Kap · `com.wulkano.kap` → `kap`
- [ ] Keka · `com.aone.keka` → `keka`
- [ ] XMind · → `xmind`
- [ ] SwitchHosts · `net.oldj.switchhosts` → `switchhosts`
- [ ] Obsidian · `md.obsidian` → `obsidian`
- [ ] AnyDesk · `com.philandro.anydesk` → `anydesk`
- [ ] CleanMyMac X · `com.macpaw.CleanMyMac4` → `cleanmymac`
- [ ] Clash Verge · `io.github.clash-verge-rev.clash-verge-rev` → `clash-verge-rev`（Rev 分支）
- [x] DBX · `com.dbx.app` → `dbx`（2026-08-27 mini 已 adopt + core 登记，三机都有；adopt 校验通过，产品确认无误）

**中国系（8）**

- [ ] 微信 · `com.tencent.xinWeChat` → `wechat`
- [ ] 企业微信 · `com.tencent.WeWorkMac` → `wechatwork`（**勿用 wecom，token 不存在**）
- [ ] Lark 国际版 · `com.electron.lark` → `lark`（飞书国内版才是 `feishu`，别装错）
- [ ] 钉钉 · `com.alibaba.DingTalkMac` → `dingtalk`
- [ ] 腾讯会议 · `com.tencent.meeting` → `tencent-meeting`
- [ ] 网易云音乐 · `com.netease.163music` → `neteasemusic`
- [ ] 微信开发者工具 · → `wechatwebdevtools`
- [ ] oss-browser（阿里云）· `com.electron.oss-browser` → `oss-browser`

**待核对（1）**

- [ ] WPS Office · `com.kingsoft.wpsoffice.mac` → `wpsoffice-cn`（中国版；国际版是 `wpsoffice`。adopt 失败即版本不对，跳过再人工确认账号体系）

### 1.2 保持手动（16，无 cask 或渠道特殊）

| App | 原因 |
|---|---|
| EasyConnect（深信服） | 内网 VPN 客户端，无官方 cask |
| PrinterClient（`com.isecstar.mpc`） | 公司打印客户端 |
| Monitoring Helper（`com.sascha-simon.helper`） | 社区工具，无 cask（core 已有 macmon） |
| cosbrowser（腾讯云） | 无 cask（注意与阿里云的 oss-browser 不同） |
| Caesium Image Compressor | 无 cask，GitHub 渠道 |
| ColorSnapper2 | 官网付费，无 cask |
| SecureFX（VanDyke） | 官网付费，无 cask |
| ToDesk | 无 cask（国内渠道） |
| marktext | 项目停更，cask 已移除 |
| Codex++（`com.bigpizzav3.codexplusplus`） | GitHub 渠道；**cask `codex` 是别的产品，勿装** |
| 微信支付商户平台证书工具 | 企业工具，无 cask |
| 淘宝开发者工具（`com.taobao.o3`） | 企业工具，无 cask |
| Apifox 企业版（`cn.apifox.app-pdv`） | **cask `apifox` 是标准版**，企业版走企业渠道 |
| ~~Cakebrew~~ | **2026-08-27 已删除**（项目停更），最终换 `cask "applite"`（免费/开源；中途试过 Cork 因 €25 付费弃用，MacMini 已登记）。pro13/pro14 上也各有手动装的 Cakebrew，可同样清理 |
| Filo（`com.filo.client`） | **cask `filo` 是 filomail 邮件客户端，疑似不同产品**，勿装 |
| 罗技 Options+（`com.logi.optionsplus`） | 官网渠道，无 cask |

### 1.3 清理决策（mini 特有，与收编独立）

- [ ] **LuLu**：core 声明着，但 app 不在磁盘。二选一：`brew install --cask lulu` 装回（出站防火墙）／不要了 → core 注释掉 + `brew uninstall lulu`
- [ ] **Sequel Ace**：core 声明着（共用），但 mini 上 app 不在。同上二选一。注意：不处理的话下次 `brew bundle install` 会自动装回来
- [ ] **Antigravity Tools**：MacMini 专属文件声明着，app 不在。同上
- [ ] Microsoft Remote Desktop 旧版（10.3.3）：Windows App（MAS 新版）已装，建议直接删 `/Applications/Microsoft Remote Desktop.app`
- [ ] ClashX Pro（1.116.1.1）：与 Clash Verge Rev 功能重复且无 cask，建议退役删除
- [ ] Magic Battery（MAS）未登记进任何 Brewfile：`mas search` 查 id 后补进对应文件

---

## 二、token 对照表（跨机复用）

> 上面 1.1/1.2 的结论浓缩成规则，另两台核对时直接套用。

**token 陷阱（勿装错）：**

| 想装的 | 正确 token | 陷阱 |
|---|---|---|
| 企业微信 | `wechatwork` | `wecom` 不存在 |
| Clash Verge | `clash-verge-rev` | 原版 `clash-verge` 已死档 |
| VS Code Insiders | `visual-studio-code@insiders` | 带 @ 的版本 token |
| Lark（国际版） | `lark` | `feishu` 是国内飞书 |
| WPS 中国版 | `wpsoffice-cn` | `wpsoffice` 是国际版 |
| Filo | 无（保持手动） | cask `filo`=filomail 邮件客户端 |
| Codex++ | 无（保持手动） | cask `codex` 是别的产品 |
| Apifox 企业版 | 无（保持手动） | cask `apifox` 是标准版 |
| ColorSnapper2 | `colorsnapper`（**无 2**） | |
| 网易云音乐 | `neteasemusic` | 不是 netease-cloud-music |
| Logitech Options+ | 无 | 官网渠道 |

**无 cask 名单**（另两台若也装了，直接归"保持手动"）：EasyConnect、PrinterClient、Monitoring Helper、cosbrowser、Caesium、ColorSnapper2、SecureFX、ToDesk、marktext、Codex++、微信支付商户平台证书工具、淘宝开发者工具、Apifox 企业版、Cakebrew、Filo、罗技 Options+。

---

## 三、执行流程（勾选完成后）

### 1. adopt 收编（不动 app 本体、无需退出 app）

> **下载坑（2026-08-27 实测）**：有些 cask 的 URL 本体直连可达，但 302 跳到 **GitHub Releases**（如 `dbeaver-community`）——直连卡死、走代理大文件易中断。解法：用 curl 断点续传直接灌进 brew 缓存，再 install 命中缓存：
> ```bash
> CACHE=$(brew --cache --cask <token>)          # 拿到缓存目标路径
> curl -L -C - --speed-time 30 --speed-limit 51200 -o "$CACHE" <cask的url>   # 走代理，可放循环里重试
> brew install --cask --adopt <token>
> ```
> **pkg 型 cask 坑（已遇到：`tailscale-app`、`microsoft-teams`）**：brew 要调 `sudo installer`，无 TTY 直接失败。在自己终端交互跑，或用文末附录的 SUDO_ASKPASS 弹窗法。

```bash
export http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897
brew install --cask --adopt <token1> <token2> ...
```

- 失败的（app 版本与 cask 不一致时 adopt 会拒绝）回退：退出 app → `rm -rf "/Applications/Xxx.app"` → `brew install --cask xxx`
- 带 root 组件的 app（如 CleanMyMac X）回退删除时可能要 sudo
- pkg 型 cask 需要 sudo，在**自己的终端**交互跑；无 TTY 环境用 SUDO_ASKPASS 弹窗法（见附录）

### 2. 登记 Brewfile（在 mini 上改 source）

- 三机通用 → `shared/Brewfile.core`；单机专属 → `shared/Brewfile.<hostname>`
- ghostty / warp 建议借此上提 core（Pro14 文件里本就有此意图）
- 流程：`chezmoi apply` → `chezmoi git -- add -A && chezmoi git -- commit -m "..." && chezmoi git -- push`
- 辅机：`chezmoi update && brew bundle install --file ~/.Brewfile`

### 3. 升级注意

`auto_updates true` 的 cask（chrome / edge / wechat / claude 等自更新型 app）`brew upgrade` 默认跳过，要 `brew upgrade --greedy` 才检查。

---

## 附录：SUDO_ASKPASS 弹窗法（无 TTY 时 brew 装 pkg 型 cask）

```bash
cat > /tmp/brew-askpass.sh <<'EOF'
#!/bin/sh
osascript -e 'display dialog "sudo 密码（brew 安装 pkg）:" default answer "" with hidden answer' -e 'text returned of result' 2>/dev/null
EOF
chmod +x /tmp/brew-askpass.sh
export SUDO_ASKPASS=/tmp/brew-askpass.sh
brew install --cask <token>   # 会弹 macOS 密码框
rm -f /tmp/brew-askpass.sh
```
