# mise 环境维护手册（本机实操记录）

> 本文档记录 **2026-08-24** 在本机（macOS arm64, Code - Insiders）为 Dulux CMS 后端项目落地 mise 的实际配置，供下次重装/换机/出问题时快速复刻。
> 上游原理见同目录 [mise-多平台配置指南.md](./mise-多平台配置指南.md)；本文只写**本机做了什么、怎么验证、怎么排错**。

---

## 0. 一句话现状

mise 已装并激活，jenv 已禁用，JDK17/Maven3.9.12 用 symlink 复用系统已装版本（零重下），后端 `mise.toml` 真正生效。VSCode（Code - Insiders）全局 settings.json 指向同一套 JDK/Maven。

---

## 1. 关键路径速查

| 项 | 路径 / 值 |
|---|---|
| mise 本体 | `/opt/homebrew/bin/mise`（Homebrew 2026.8.11） |
| mise installs 根 | `~/.local/share/mise/installs/` |
| JDK17 symlink | `~/.local/share/mise/installs/java/17 → /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` |
| Maven symlink | `~/.local/share/mise/installs/maven/3.9.12 → /usr/local/apache-maven-3.9.12` |
| 后端 mise 配置 | `backend/mise.toml`（即 `dulux-cms-parent/mise.toml`） |
| shell hook | `~/.zshrc` 内 `eval "$(mise activate zsh)"` |
| jenv 备份 | `~/.zshrc.bak.20260824-162337`（注释了 jenv 两行） |
| VSCode 全局配置 | `~/Library/Application Support/Code - Insiders/User/settings.json` |
| 后端 pom JDK | `<java.version>17</java.version>` |

> JDK17 走 `opt` 路径而非 `Cellar/17.0.19/`——升级小版本后 Cellar 路径变、symlink 会断（指南踩坑#2）。

---

## 2. 从零复刻（换机/重装顺序）

### 2.1 装 mise + hook

```bash
brew install mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
```

### 2.2 禁用旧管理器（避免 PATH 冲突，指南踩坑#5）

注释 `~/.zshrc` 里的 jenv 行：
```bash
# export PATH="$HOME/.jenv/bin:$PATH"
# eval "$(jenv init -)"
```
direnv/asdf/SDKMAN 同理注释。

### 2.3 symlink 复用系统 JDK / Maven

```bash
MISE_JAVA="$HOME/.local/share/mise/installs/java"
MISE_MVN="$HOME/.local/share/mise/installs/maven"
mkdir -p "$MISE_JAVA" "$MISE_MVN"
ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home "$MISE_JAVA/17"
ln -sfn /usr/local/apache-maven-3.9.12 "$MISE_MVN/3.9.12"
```

> 若系统没装 openjdk@17：`brew install openjdk@17`。
> 若要复用 JDK8/21：同理 `ln -sfn /Library/Java/JavaVirtualMachines/jdk-1.8.jdk/Contents/Home "$MISE_JAVA/8"`。

### 2.4 确认后端 mise.toml（已就位，一般不动）

`backend/mise.toml`：
```toml
[tools]
java  = "17"
maven = "3.9.12"
```
> mise 同时读 `.mise.toml` 和 `mise.toml`，二选一即可，本仓库用 `mise.toml`。

### 2.5 验证

```bash
exec zsh                       # 重载 shell
mise ls java                   # 应见 17 (symlink)
mise ls maven                  # 应见 3.9.12 (symlink)
cd backend && mise current     # 应输出 java 17 / maven 3.9.12
java -version                  # 17.0.19
mvn -v                         # Apache Maven 3.9.12, runtime 17.0.19
```

`(symlink)` 标记 = 复用系统那份，未重下。

### 2.6 配 VSCode（Code - Insiders）

全局 `~/Library/Application Support/Code - Insiders/User/settings.json` 加：
```jsonc
{
  "java.jdt.ls.vmargs": "-javaagent:/Users/qiuwenbo/.m2/repository/org/projectlombok/lombok/1.18.42/lombok-1.18.42.jar",
  "java.jdt.ls.java.home": "/Users/qiuwenbo/.local/share/mise/installs/java/17",
  "java.configuration.runtimes": [
    { "name": "JavaSE-17", "path": "/Users/qiuwenbo/.local/share/mise/installs/java/17", "default": true }
  ],
  "maven.executable.path": "/usr/local/apache-maven-3.9.12/bin/mvn"
}
```
改完 `Cmd+Shift+P` → `Java: Clean Java Language Server Workspace`（Restart），再 `Developer: Reload Window`。

> ⚠️ JDT 语言服务本身需 JDK17+ 启动；之前全局配的是 `jdk-1.8`，会导致 Java 扩展跑不起来——务必指 17。

---

## 3. 三层一致性检查表

CLI / 终端 / VSCode Java 扩展 / Maven 扩展 四处必须指向**同一套 JDK17**，否则会出现"终端能编译、IDE 报红"或反之。

| 层 | 看哪里 | 期望 |
|---|---|---|
| 终端 | `cd backend && java -version` | 17.0.19 |
| 终端 | `cd backend && mvn -v` | 3.9.12 / runtime 17.0.19 |
| mise | `mise current`（在 backend） | java 17, maven 3.9.12 |
| VSCode JDT LS | settings `java.jdt.ls.java.home` | mise java/17 symlink |
| VSCode 项目 runtime | settings `java.configuration.runtimes` | JavaSE-17 → 同 symlink |
| VSCode Maven | settings `maven.executable.path` | /usr/local/apache-maven-3.9.12/bin/mvn |

---

## 4. 排错速查

| 症状 | 排查 | 修复 |
|---|---|---|
| `mise: command not found` | mise 没装 / hook 没生效 | `brew install mise`；`~/.zshrc` 有 `eval "$(mise activate zsh)"`；`exec zsh` |
| `mise current` 不切版本 | 不在含 `mise.toml` 的目录 | `cd backend`（聚合根没有 mise.toml，需进 backend） |
| `mise ls java` 没有 (symlink) | symlink 没建/断了 | 重跑 §2.3；`command ls -la ~/.local/share/mise/installs/java/` |
| JDK17 升级后 `java` 报路径不存在 | 用了 Cellar 路径建 symlink | 重建用 `opt` 路径：`ln -sfn /opt/homebrew/opt/openjdk@17/...` |
| PATH 里多个 java 互相覆盖 | jenv/asdf 没禁干净 | `~/.zshrc` 注释 jenv；`echo $PATH` 看 `/usr/bin` 前有没有残留 |
| 终端能跑、VSCode Java 扩展报红 | JDT LS 没指 17 或没 Reload | 查 §2.6 settings；`Java: Clean Java Language Server Workspace` |
| VSCode Maven 找不到 mvn | 从 Dock 启动没继承 mise PATH | settings 里写死 `maven.executable.path`（已写） |
| `mvn` 用错 JDK | `JAVA_HOME` 被别处 export | `echo $JAVA_HOME`；mise 默认不设 JAVA_HOME，靠 shim；如需可在 `mise.toml` `[env]` 显式设 |
| `mise current` 是 8 但 `java -version` 仍 17 | `.zshrc` 残留 `export PATH="$(brew --prefix openjdk@17)/bin:$PATH"`（上 mise 前手动加的），在 PATH 里压过项目级 JDK | 注释该行；`grep -n "openjdk@" ~/.zshrc` 找到后加 `#`；mise 接管后此 export 有害无益 |
| `which java` 显示 `/usr/bin/java` 而非 mise 路径 | macOS 的 `/usr/bin/java` 是桩，尊重 `JAVA_HOME`；mise 设了 JAVA_HOME 就会走对应 JDK | 正常，无需处理；`java -version` 输出版本对即可 |
| 新建 `mise.toml` 不生效，报 `not trusted` | mise 安全机制：新 config 文件首次需手动 trust | `mise trust <path/to/mise.toml>`；**每个新建 mise.toml 都要 trust 一次**（drplant/前端都中过） |
| 前端目录 `which node` 还是 nvm 的 node | nvm 在别处被加载，或当前会话继承了禁用前的旧 PATH | `grep -rn "nvm\|NVM_DIR" ~/.zshrc ~/.zprofile ~/.zshenv \| grep -v '#'` 查残留；新开终端清掉继承 PATH；确认 mise.toml 已 trust |

---

## 5. 回滚

恢复到 jenv 时代：
```bash
cp ~/.zshrc.bak.20260824-162337 ~/.zshrc
exec zsh
# symlink 留着无害；要删：
rm ~/.local/share/mise/installs/java/17
rm ~/.local/share/mise/installs/maven/3.9.12
```
VSCode 全局 settings 的 `java.*`/`maven.*` 三项改回原值（原 `java.jdt.ls.java.home` 是 jdk-1.8，**不建议回滚**——本就是错的）。

---

## 6. 维护原则

- **版本声明下沉到 `backend/mise.toml`**，纯版本号可提交、团队共享；本机绝对路径只进 VSCode 全局 settings / symlink，不进 git。
- **加版本只装不重下**：新 JDK 用 `ln -sfn <系统路径> ~/.local/share/mise/installs/java/<ver>` 接入，mise 当"已装"，不要让 mise 自己下。
- **跨平台一份配置**：`mise.toml` 是纯版本号，macOS/Linux/Windows 都读同一份；各平台只差 symlink 建法（Windows 见指南 §4.4，需开发者模式）。
- **IDEA / VSCode 各自配一次**，指向 mise 接入的同一 symlink，CLI 改 mise.toml 不影响 IDE，反之亦然。

---

## 7. 变更日志

| 日期 | 变更 |
|---|---|
| 2026-08-24 | 初次落地：装 mise + hook、禁 jenv、JDK17/Maven3.9.12 symlink 复用、修 VSCode 全局 JDT LS 从 jdk-1.8 → mise java/17、补 runtimes 与 maven.executable.path |
| 2026-08-24 | 接入 drplant-cis-parent（JDK8 项目）：建 installs/java/8 symlink 复用系统 Oracle JDK8、`mise install maven@3.6.3`、写项目级 mise.toml + .vscode/settings.json（后者 gitignore）；踩坑：`.zshrc:200` 拊留 `brew --prefix openjdk@17/bin` export 压过项目级 JDK8，已注释 |
| 2026-08-24 | 接入 dulux-cms-front-parent（前端，原 .nvmrc+nvm）：`mise install node@22.14.0 + pnpm@11.9.0`、写 mise.toml（node+pnpm）、注释 .zshrc 226-258 整块 nvm auto-switch、`mise trust`；保留 .nvmrc 作团队参考；nvm 本体未卸（待 mise 稳定后可选清理） |
| 2026-08-24 | 接入 drplant-cis-front-parent（前端老项目，webpack4/react16，原 .nvmrc=v16.20.2）：`mise install node@16.20.2 + yarn@1.22.19`、写 mise.toml（node+yarn）、`mise trust`。注意：.nvmrc 带 `v` 前缀，mise.toml 用无 `v` 的 `16.20.2` |

---

## 8. 多语言项目并存（Java / Node 全由 mise 接管）

本机现在 Java + Node 多项目交替开发，mise 按**进目录**自动切，无需手动：

| 进哪个目录 | 自动切到 |
|---|---|
| `cd .../dulux-cms-parent`（backend） | java 17 / maven 3.9.12 |
| `cd .../drplant-cis-parent` | java 8 / maven 3.6.3 |
| `cd .../dulux-cms-front-parent`（前端） | node 22.14.0 / pnpm 11.9.0 |
| `cd .../drplant-cis-front-parent`（前端老项目） | node 16.20.2 / yarn 1.22.19 |
| 其它无 mise.toml 的目录 | 走全局默认（`mise use -g java@17`、`mise use -g node@22` 设的，见指南 §5） |

### 接入新 JDK 项目三步

1. **复用系统 JDK**（若有）：`ln -sfn <系统JDK Home> ~/.local/share/mise/installs/java/<ver>`
   - 系统无该版本：`brew install openjdk@<ver>`（mac arm64 注意：JDK8 别用 temurin@8 纯 x64，用 Oracle/Liberica/Corretto/Zulu 的 arm64 原生版）
2. **Maven**：`mise install maven@<ver>`（下载，不复用），或系统已装则 symlink 复用
3. **写项目 mise.toml + .vscode/settings.json**：
   - `mise.toml`：纯版本号，提交团队共享
   - `.vscode/settings.json`：项目级 runtimes 指该 JDK（覆盖全局默认），加进 `.gitignore` 不提交

### VSCode 多项目注意

全局 settings 锁了 `JavaSE-17 default`；JDK8 项目要在**项目级** `.vscode/settings.json` 覆盖 runtimes 指 `JavaSE-1.8`，项目级优先于用户级，互不干扰。切换 VSCode 窗口后 `Java: Clean Java Language Server Workspace` 让 JDT LS 按项目 JDK 重启。

### 从 nvm 迁移前端到 mise

1. 看 `.nvmrc` 取版本号，`mise install node@<ver>` + `mise install pnpm@<ver>`（pnpm 版本看 `package.json` 的 `packageManager` 字段）
2. 写 `mise.toml`：`node = "<ver>"`、`pnpm = "<ver>"`，可留 `[env]` NODE_OPTIONS 占位
3. **禁用 nvm**：注释 `~/.zshrc` 的 `NVM_DIR` + `load-nvmrc` chpwd 钩子整块（不能只注释前两行，chpwd 钩子会报 `nvm` not found 警告）
4. `mise trust <path/to/mise.toml>` ——**必做**，否则 mise 报 not trusted 不切版本
5. 验证：新开终端（不是当前 tab，当前 tab 继承旧 PATH）`cd 前端 && which node` 应是 `~/.local/share/mise/installs/node/<ver>/bin/node`
6. `.nvmrc` 可保留（团队/CI 参考，mise.toml 优先级更高，不冲突）
7. **node_modules 不用重装**：nvm 和 mise 用同版本 node，ABI 一致
8. nvm 本体可后续 `brew uninstall nvm && rm -rf ~/.nvm` 彻底清理（会删缓存的多版本 node，确认 mise 稳定后再做）
