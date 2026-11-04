# mise 多平台配置指南（复用系统 JDK/Maven）

> 跨 **macOS / Linux / Windows（原生 + WSL2）** 的统一方案。
> 核心思想：**mise 管多版本 + 按目录自动切；系统已装的 JDK/Maven 用 symlink 接入复用，零重复下载；一份 `.mise.toml` 全平台共享。**

---

## 一、为什么是 mise

| 痛点 | mise 解法 |
|------|----------|
| 多 JDK 共存（8/11/17/21/26） | `.mise.toml` 声明，进目录自动切 |
| JDK + Maven 要配对（8↔3.6.3、17↔3.9.12） | 同一 toml 锁两个工具 |
| 已装 JDK/Maven 不想重下 | symlink 进 `installs/` 复用 |
| 跨平台配置不一致 | `.mise.toml` + `mise activate` 各平台通用 |
| 顺带要管 env（MAVEN_OPTS 等） | `[env]` 段 |

**与同类对比**：jenv 只管 JDK 不管 Maven；SDKMAN 不管 Windows 原生；direnv 是 env 钩子需自写 helper 且 Windows 不原生。mise 全覆盖。

---

## 二、安装

### 2.1 macOS（Homebrew）

```bash
brew install mise
```

### 2.2 Linux（APT / 一键脚本）

**Debian/Ubuntu（APT 源）**:

```bash
sudo install -dm 755 /etc/apt/keyrings
wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor \
  | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/mise.list
sudo apt update && sudo apt install -y mise
```

**任意发行版（一键脚本）**:

```bash
curl https://mise.run | sh
```

**Homebrew on Linux**:

```bash
brew install mise
```

### 2.3 Windows 原生（scoop / winget）

```powershell
# scoop（推荐）
scoop install mise

# 或 winget
winget install jdx.mise
```

> ⚠️ **symlink 需开发者模式**：设置 → 隐私和安全 → 开发者选项 → 开启"开发人员模式"。否则后面 `New-Item SymbolicLink` 会失败。

### 2.4 Windows WSL2

WSL 内是 Linux，**完全按 2.2 装**。注意：WSL 的 JDK 要在 WSL 内独立装，**不要跨 `/mnt/c` 用 Windows 的 JDK**（IO 慢 + 路径分隔符冲突）。

---

## 三、Shell Hook（让"进目录自动切"生效）

### zsh（macOS 默认 / Linux 常见）

```bash
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
```

### bash（Linux / Git Bash）

```bash
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
```

### fish

mise 安装时已自动激活，无需手动配置。

### PowerShell（Windows 原生）

```powershell
# 打开 profile
notepad $PROFILE
# 加入一行：
mise activate powershell | Out-String | Invoke-Expression
```

> 改完 **新开终端** 或 `exec zsh`（macOS/Linux）/ 重启 PowerShell 才生效。

---

## 四、接入系统 JDK / Maven（复用，不重下）

mise 默认自己下载工具。复用系统已装的，把 JDK/Maven 目录 **symlink 进 mise 的 installs 目录**，mise 当作"已装"，不再下载。

### 4.1 各平台 installs 路径

| 平台 | installs 根目录 |
|------|----------------|
| macOS | `~/.local/share/mise/installs/` |
| Linux / WSL | `~/.local/share/mise/installs/` |
| Windows 原生 | `%LOCALAPPDATA%\mise\installs\`（即 `C:\Users\<你>\AppData\Local\mise\installs\`） |

可用环境变量 `MISE_DATA_DIR` 改根。

### 4.2 查系统 JDK 路径

```bash
# macOS（java_home 是 macOS 专有，最准）
/usr/libexec/java_home -V          # 列全部
/usr/libexec/java_home -v 17       # 定位 JDK17

# Linux
ls /usr/lib/jvm/                   # 看已装
update-alternatives --list java    # Debian 系

# Windows PowerShell
Get-ChildItem "C:\Program Files\Java"
where.exe java                     # 反查 PATH 里的 java
```

### 4.3 macOS / Linux（symlink）

```bash
MISE_JAVA="$HOME/.local/share/mise/installs/java"
MISE_MVN="$HOME/.local/share/mise/installs/maven"
mkdir -p "$MISE_JAVA" "$MISE_MVN"

# JDK（版本号自定义，= 后续 .mise.toml 用的名）
ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home "$MISE_JAVA/17"
ln -sfn /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home "$MISE_JAVA/11"
ln -sfn /Library/Java/JavaVirtualMachines/liberica-jdk-8.jdk/Contents/Home   "$MISE_JAVA/8"

# Maven
ln -sfn "$HOME/Develop/apache-maven-3.6.3" "$MISE_MVN/3.6.3"
```

> `-sfn`：`-s` 符号链接，`-f` 覆盖已存在，`-n` 不解引用（避免链到目标内部）。
>
> **macOS 用 `opt` 路径不用 `Cellar/<版本号>`**：`/opt/homebrew/opt/openjdk@17/...` 跨 JDK 小版本升级稳定；`Cellar/17.0.19/...` 升级后路径变、symlink 断。

### 4.4 Windows 原生（PowerShell）

```powershell
$j = "$env:LOCALAPPDATA\mise\installs\java"
$m = "$env:LOCALAPPDATA\mise\installs\maven"
New-Item -ItemType Directory -Force $j,$m | Out-Null

# JDK（需开发者模式，见 2.3）
New-Item -ItemType SymbolicLink -Path "$j\17" -Target "C:\Program Files\Java\jdk-17"
New-Item -ItemType SymbolicLink -Path "$j\8"  -Target "C:\Program Files\Java\jdk1.8.0_412"

# Maven
New-Item -ItemType SymbolicLink -Path "$m\3.6.3" -Target "C:\Tools\apache-maven-3.6.3"
```

或 cmd: `mklink /D "%LOCALAPPDATA%\mise\installs\java\17" "C:\Program Files\Java\jdk-17"`（管理员 cmd）。

### 4.5 验证接入

```bash
mise ls java          # 输出带 (symlink) = 复用成功，未重下
mise ls maven
```

---

## 五、项目配置 `.mise.toml`

项目根目录放 `.mise.toml`（**可提交，团队共享**，纯版本号无本机路径）:

```toml
# .mise.toml
[tools]
java  = "17"        # 版本号 = symlink 目录名 / 或 mise 下载的版本
maven = "3.9.12"

[env]
MAVEN_OPTS = "-Xmx2g"
JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"
SPRING_PROFILES_ACTIVE = "dev"
```

### 各项目示例

```toml
# JDK8 老项目（如 hyt-parent）
[tools]
java  = "8"
maven = "3.6.3"
```

```toml
# JDK21 新项目
[tools]
java  = "21"
maven = "3.9.12"
```

### 全局默认

```bash
mise use -g java@17        # 全局默认 JDK17（写 ~/.config/mise/config.toml）
mise use -g maven@3.9.12
```

没有 `.mise.toml` 的目录走全局默认。

---

## 六、常用命令速查

| 命令 | 作用 |
|------|------|
| `mise ls` | 已装的所有工具版本 |
| `mise ls java` | java 已装版本（symlink 的标 `(symlink)`） |
| `mise ls-remote java` | java 可下载的全部版本/发行版 |
| `mise use java@17` | 当前项目绑 JDK17（写 `.mise.toml`） |
| `mise use -g java@17` | 全局默认 |
| `mise install` | 按 `.mise.toml` 装齐缺失的 |
| `mise install maven@3.9.12` | 装指定版本（mise 自己下，不复用） |
| `mise current` | 当前激活的版本 |
| `mise outdated` | 可升级的 |
| `mise upgrade` | 升级 |
| `mise uninstall java@8` | 卸某版（**不碰** symlink 指的系统 JDK） |
| `mise registry` | 列所有支持工具 + backend |
| `mise exec -- java -version` | 在当前 .mise.toml 环境跑命令（不 activate 也能测） |

---

## 七、IDEA 配置（独立，每项目一次）

IDEA **不认 `.mise.toml`**，需手动指（和 CLI 各管各，但指向**同一套 JDK**）:

1. `File → Project Structure → SDKs → +` 加 JDK（选 mise 接入的那个路径）
2. `Project Structure → Project → SDK` 选对应 JDK
3. `Settings → Build Tools → Maven → Maven home` 指 Maven 目录
4. `Runner → JRE` 选运行 Maven 的 JDK

> CLI 改 `.mise.toml` 不影响 IDEA，反之亦然。两边指向同一 JDK 即一致。
> 切版本后 IDEA 里 `Reload All Maven Projects`，必要时关 Maven daemon。

---

## 八、踩坑

1. **activate 不生效**：新开终端，或 `exec zsh` / 重启 PowerShell。
2. **macOS symlink 路径用 `opt` 不用 `Cellar/<ver>`**：升级后 Cellar 路径变。
3. **Windows symlink 失败**：开"开发人员模式"，或用管理员 cmd 的 `mklink`。
4. **版本号要一致**：`.mise.toml` 里 `java = "8"` 必须 = symlink 目录名 `installs/java/8`。自定义命名即可，不必用 mise 官方 `temurin-8.x.x` 格式。
5. **别和 jenv/asdf/SDKMAN 同时管 JDK**：PATH 互相覆盖，切版本不可预测。装 mise 前禁用旧工具（注释其 shell 配置）。
6. **WSL 别跨 `/mnt/c` 用 Windows JDK**：WSL 内独立装 JDK（apt/SDKMAN），再 symlink。
7. **JDK8 arm64 选 Liberica/Corretto/Zulu**：mac arm64 上别用 temurin@8（纯 x64 走 Rosetta）。
8. **Maven 复用 vs 重下**：复用系统那份用 symlink；要 mise 全权管用 `mise install maven@<ver>`（下到 installs，和 symlink 共存）。
9. **`.mise.toml` 含本机绝对路径时别提交**：纯版本号（`java="17"`）可提交；`path:...` 形式不提交。

---

## 九、从其他工具迁移

### jenv → mise

```bash
# 1. 注释 .zshrc 的 jenv
# export PATH="$HOME/.jenv/bin:$PATH"
# eval "$(jenv init -)"
# 2. 加 mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
# 3. JDK symlink 进 mise（见四）
# 4. 项目 .java-version → .mise.toml
```

### direnv → mise

把 `.envrc` 的自建 helper:

```bash
use jdk 1.8
use mvn 3.6.3
```

换成 `.mise.toml`:

```toml
[tools]
java  = "8"
maven = "3.6.3"
```

`direnvrc` 里的 `use_jdk/use_mvn` helper 可删。env 变量从 `.envrc` 的 `export` 搬到 `[env]` 段。

---

## 十、附录：macOS 实操快照（参考）

- **mise**：2026.7.15（Homebrew）
- **hook**：`~/.zshrc` 加 `eval "$(mise activate zsh)"`，原 jenv 配置已注释
- **接入 JDK**（全 symlink 复用）：
  - `8` → Liberica 1.8.0_502（arm64 原生）
  - `11` → OpenJDK 11.0.31（Homebrew）
  - `17` → OpenJDK 17.0.19（Homebrew）
  - `26` → OpenJDK 26.0.1（Homebrew）
- **接入 Maven**：`3.6.3` → `~/Develop/apache-maven-3.6.3`
- **验证**：`mise ls java` 全显 `(symlink)`，复用未重下

---

*维护原则一句话：版本声明下沉到项目 `.mise.toml`，系统工具用 symlink 复用，加版本只装不重下，跨平台一份配置。*
