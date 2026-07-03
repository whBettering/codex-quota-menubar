这是一份为您的小工具 `CodexQuotaMenubar` 编写的中文使用指南。您可以将其直接添加到项目的 `README.md` 文件中。
<img width="492" height="98" alt="image" src="https://github.com/user-attachments/assets/4479e828-6395-46f5-9f7f-0e2d6e0b5620" />
<img width="528" height="251" alt="image" src="https://github.com/user-attachments/assets/6e2edd12-e8e2-4854-b8ce-9160d5479634" />
<img width="487" height="137" alt="image" src="https://github.com/user-attachments/assets/3a0b7149-86cc-4fd2-9a68-7fb0b513caf3" />

---

## 使用指南 (Usage Guide)

`CodexQuotaMenubar` 是一款专为 macOS 设计的菜单栏工具，旨在帮助您实时监控 Codex 的配额使用情况。

### 🚀 安装说明

目前该工具通过 GitHub Releases 发布：

1. 前往 [GitHub Releases 页面](https://github.com/whBettering/codex-quota-menubar/releases) 下载最新版本的 `CodexQuotaMenubar-<version>.dmg` 文件。
2. 打开下载的 `.dmg` 文件，将 `CodexQuotaMenubar.app` 拖拽到您的 **应用程序 (Applications)** 文件夹中。
3. 从 Spotlight 或“应用程序”文件夹中启动该程序。

> **注意**：由于目前的发行版本未经过 Apple 签名，若系统弹出安全提示导致无法运行，请在“应用程序”文件夹中**右键点击**该 App，选择 **“打开”**，并在弹出的对话框中再次确认即可。后续运行将不再受此影响。

---

### 🛠 开发者指南

如果您希望从源代码运行或参与开发，请参考以下操作：

#### 1. 从源码运行

直接在终端执行以下命令即可启动：

```bash
swift run CodexQuotaMenubar

```

#### 2. 构建 App Bundle

将项目编译为 macOS 应用包（输出路径：`dist/CodexQuotaMenubar.app`）：

```bash
./scripts/build-app.sh

```

#### 3. 构建发布版 DMG

生成可分发的 `.dmg` 安装包（输出路径：`dist/release/CodexQuotaMenubar-<version>.dmg`）：

```bash
./scripts/package-release.sh

```

#### 4. 验证与测试

在提交代码前，建议运行以下测试确保功能正常：

```bash
# 运行核心测试
swift run CodexQuotaCoreTests

# 运行构建测试
swift build
bash scripts/test-release-contract.sh

```

---

### 💡 常见问题 (FAQ)

* **Q: 这个工具支持哪些系统版本？**
* A: 本工具主要适配 macOS 环境，建议在较新的 macOS 版本上使用。


* **Q: 软件无法打开怎么办？**
* A: 请参照安装说明中的“右键点击 -> 打开”步骤，以绕过未签名应用的权限限制。



---

希望这份指南能帮助到您的用户！如果您需要针对某个特定的功能点（例如如何配置 API 密钥等）进行补充，欢迎随时告诉我。
