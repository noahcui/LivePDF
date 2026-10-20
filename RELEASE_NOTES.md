A native macOS PDF reader that reloads changed files and preserves your reading position.

macOS 原生 PDF 阅读器，文件更新后自动重载，并保留阅读位置。

**Apple Silicon · macOS 14+ · English / 简体中文**

[English](#english) · [简体中文](#简体中文)

## Downloads / 下载

| File / 文件 | Purpose / 用途 |
| --- | --- |
| [LivePDF-1.0.2-arm64.pkg](https://github.com/noahcui/LivePDF/releases/download/v1.0.2/LivePDF-1.0.2-arm64.pkg) | **Recommended / 推荐** — macOS installer / 安装包 |
| [LivePDF-1.0.2-source.zip](https://github.com/noahcui/LivePDF/releases/download/v1.0.2/LivePDF-1.0.2-source.zip) | Source snapshot / 源码快照 |
| [SHA256SUMS-v1.0.2.txt](https://github.com/noahcui/LivePDF/releases/download/v1.0.2/SHA256SUMS-v1.0.2.txt) | SHA-256 checksums / 文件校验清单 |

### Verify downloads / 校验下载

Download all three files into the same directory, then run the following command. Both the installer and source archive are listed in the checksum file.

将上述三个文件放在同一目录后运行以下命令；清单会同时校验安装包和源码包。

```sh
shasum -a 256 -c SHA256SUMS-v1.0.2.txt
```

## English

### What’s new

- Added English and Simplified Chinese support to the app and installer, including menus, controls, status messages, and app-defined errors.
- Added regional language matching, English fallback, and localization tests. The app respects macOS per-app language preferences after restarting.
- Fixed direct executable launches treating macOS language-option values as PDF filenames.

### Install and open

Open `LivePDF-1.0.2-arm64.pkg` and follow the installer. Administrator approval is required. It installs the app at `/Applications/LivePDF.app` and the command at `/usr/local/bin/livepdf`. Running the installed app requires no developer tools or TeX.

Launch LivePDF from Applications, use Finder’s **Open With** menu, or run:

```sh
livepdf paper.pdf
```

If `/usr/local/bin` is absent from your PATH, use `/usr/local/bin/livepdf` directly.

### Installation notes and validation

The installer is not Developer ID signed or Apple notarized; the app has an ad-hoc integrity signature. If macOS blocks it because the developer cannot be verified, confirm the download’s origin and checksum, try opening it, then look for **System Settings → Privacy & Security → Open Anyway**. See [Apple’s instructions](https://support.apple.com/en-us/102445).

The recorded v1.0.2 acceptance run passed **31 automated tests**, covering file watching, incomplete writes, position restoration, and localization. Package structure, app integrity, architecture, minimum deployment target, and language resources were also checked. Installation and visual behavior still need confirmation on the target Mac; macOS 14 has not been tested on a separate machine.

See the [usage guide](https://github.com/noahcui/LivePDF/blob/main/README.md#use), [reload behavior](https://github.com/noahcui/LivePDF/blob/main/README.md#reload-behavior-and-configuration), and [manual checklist](https://github.com/noahcui/LivePDF/blob/main/README.md#tests-and-manual-checks) for details.

## 简体中文

### 本版更新

- 应用和安装器新增英语与简体中文支持，覆盖菜单、控件、状态提示及应用自有错误信息。
- 新增语言及地区匹配、英语回退和本地化测试；应用支持 macOS 单个 app 的语言偏好，修改后重启生效。
- 修复直接运行可执行文件时，将 macOS 语言选项的参数值误当作 PDF 文件名的问题。

### 安装与打开

双击 `LivePDF-1.0.2-arm64.pkg`，按安装器提示操作，需要管理员授权。应用安装到 `/Applications/LivePDF.app`，命令安装到 `/usr/local/bin/livepdf`。运行已安装的应用无需开发工具或 TeX。

从“应用程序”启动 LivePDF，在 Finder 的“打开方式”中选择它，或运行：

```sh
livepdf paper.pdf
```

如果 PATH 不含 `/usr/local/bin`，可直接使用 `/usr/local/bin/livepdf`。

### 安装须知与验证

安装包没有 Developer ID 签名或 Apple 公证；app 使用 ad-hoc 完整性签名。如果 macOS 因无法验证开发者而阻止打开，确认来源和校验值后，先尝试打开，再到“系统设置 → 隐私与安全性”中查找“仍要打开”。详见 [Apple 的说明](https://support.apple.com/zh-cn/102445)。

v1.0.2 的已有验收记录为 **31 项自动化测试全部通过**，覆盖文件监听、不完整写入、位置恢复和本地化。安装包结构、app 完整性、架构、最低部署目标及语言资源也已核查。仍需在目标 Mac 确认安装和视觉表现；尚未在另一台 macOS 14 设备上实测。

详细操作见[使用指南](https://github.com/noahcui/LivePDF/blob/main/README.md#使用)、[重载机制](https://github.com/noahcui/LivePDF/blob/main/README.md#重载机制与配置)和[手动验收清单](https://github.com/noahcui/LivePDF/blob/main/README.md#测试与手动验收)。

---

[Changelog / 更新记录](https://github.com/noahcui/LivePDF/blob/main/CHANGELOG.md) · [MIT License / 许可证](https://github.com/noahcui/LivePDF/blob/main/LICENSE)
