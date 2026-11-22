# LivePDF 1.2.0

A native macOS PDF, Markdown, and PowerPoint reader that reloads changed files and preserves your reading position when possible.

macOS 原生 PDF、Markdown 与 PowerPoint 阅读器，文件更新后自动重载，并尽量保留阅读位置。

**Apple Silicon · macOS 14+ · English / 简体中文**

[English](#english) · [简体中文](#简体中文)

## Downloads / 下载

Download the installer, source snapshot, and checksum file from this release.

本版提供安装包、源码快照和校验清单。

| File / 文件 | Purpose / 用途 |
| --- | --- |
| [LivePDF-1.2.0-arm64.pkg](https://github.com/noahcui/LivePDF/releases/download/v1.2.0/LivePDF-1.2.0-arm64.pkg) | macOS installer / 安装包 |
| [LivePDF-1.2.0-source.zip](https://github.com/noahcui/LivePDF/releases/download/v1.2.0/LivePDF-1.2.0-source.zip) | Source snapshot / 源码快照 |
| [SHA256SUMS-v1.2.0.txt](https://github.com/noahcui/LivePDF/releases/download/v1.2.0/SHA256SUMS-v1.2.0.txt) | SHA-256 checksums / 文件校验清单 |

### Verify files / 校验文件

Place all three files in the same directory, then run the following command. Both the installer and source archive are listed in the checksum file.

将上述三个文件放在同一目录后运行以下命令；清单会同时校验安装包和源码包。

```sh
shasum -a 256 -c SHA256SUMS-v1.2.0.txt
```

## English

### What’s new

- Added PowerPoint files: `.pptx`, `.ppt`, `.ppsx`, and `.pps` open through the open panel, Finder, drag and drop, and the command line.
- LivePDF asks an installed Microsoft PowerPoint or Keynote to export the presentation to PDF and shows it in a normal PDF window, so page, zoom, display mode, search, and page navigation work as they do for PDFs.
- Saving the presentation reloads the window. Incomplete files are never sent to the converter, and a failed conversion keeps the last valid slides on screen.
- English and Simplified Chinese messages explain a missing application, missing Automation permission, and an application that does not respond.

### Install and open

Open `LivePDF-1.2.0-arm64.pkg` and follow the installer. Administrator approval is required. It installs the app at `/Applications/LivePDF.app` and the command at `/usr/local/bin/livepdf`. An Apple Silicon Mac running macOS 14 or later is required. Running the installed app requires no developer tools or TeX.

Launch LivePDF from Applications, use Finder’s **Open With** menu, or run:

```sh
livepdf paper.pdf "notes with spaces.md" slides.pptx
```

If `/usr/local/bin` is absent from your PATH, use `/usr/local/bin/livepdf` directly. PDF, Markdown, and PowerPoint documents can remain open together in separate windows.

### PowerPoint scope

Showing a presentation requires Microsoft PowerPoint or Keynote on the same Mac; PDF and Markdown need nothing else. The first time, macOS asks whether LivePDF may control that application. Allow it, or enable it later under **System Settings → Privacy & Security → Automation**. Because the app is ad-hoc signed, macOS may ask again after an update.

Each reload takes from under a second to a few seconds, may launch the application, and briefly opens a private copy of the file in it. Animations, transitions, and media are not shown. While the application is showing a dialog it cannot answer scripts; LivePDF then reports that it did not respond and keeps the last valid slides. PowerPoint is tried first, then Keynote; the README describes how to change the order and the timeout.

### Validation and signing

On the development Mac with Microsoft PowerPoint 16.114, the app’s converter exported a three-slide `.pptx` containing Chinese text to a three-page PDF with matching text, and saving a changed deck started a new conversion in the running app. The presentation window was not inspected visually. The Keynote fallback was not exercised and should be treated as untested. Markdown and PDF behavior is unchanged from 1.1.0; automated tests cover file classification, incomplete-file rejection, converter ordering, and error classification.

The app has an ad-hoc integrity signature. The installer is not Developer ID signed or Apple notarized. Installation and first launch on another target Mac remain to be confirmed; this release has not been tested on a separate macOS 14 machine.

See the [usage guide](https://github.com/noahcui/LivePDF/blob/v1.2.0/README.md#use) and [PowerPoint details](https://github.com/noahcui/LivePDF/blob/v1.2.0/README.md#powerpoint-presentations-120) for details.

## 简体中文

### 本版更新

- 新增 PowerPoint 文件支持：可通过打开面板、Finder、拖放和命令行打开 `.pptx`、`.ppt`、`.ppsx`、`.pps`。
- LivePDF 让本机安装的 Microsoft PowerPoint 或 Keynote 把演示文稿导出为 PDF，并用普通 PDF 窗口显示，因此页码、缩放、显示模式、搜索和跳页与 PDF 一致。
- 保存演示文稿后窗口自动刷新。未写完的文件不会送去转换；转换失败时保留上次有效的幻灯片。
- 未安装转换应用、未授予自动化权限、应用没有响应时，提供英语与简体中文提示。

### 安装与打开

双击 `LivePDF-1.2.0-arm64.pkg`，按安装器提示操作，需要管理员授权。应用安装到 `/Applications/LivePDF.app`，命令安装到 `/usr/local/bin/livepdf`。需要 Apple Silicon Mac 和 macOS 14 或更新版本；运行已安装的应用无需开发工具或 TeX。

从“应用程序”启动 LivePDF，在 Finder 的“打开方式”中选择它，或运行：

```sh
livepdf paper.pdf "有 空格的笔记.md" slides.pptx
```

如果 PATH 不含 `/usr/local/bin`，可直接使用 `/usr/local/bin/livepdf`。PDF、Markdown 和 PowerPoint 可以分别在多个窗口中同时阅读。

### PowerPoint 支持范围

显示演示文稿需要同一台 Mac 上装有 Microsoft PowerPoint 或 Keynote；PDF 和 Markdown 不需要其他软件。首次使用时，macOS 会询问是否允许 LivePDF 控制该应用；请允许，或稍后在“系统设置 → 隐私与安全性 → 自动化”中开启。由于 app 使用 ad-hoc 签名，更新后 macOS 可能再次询问。

每次刷新耗时不到一秒到几秒，可能会启动该应用，并在其中短暂打开文件的一份私有副本。不显示动画、切换效果和媒体。应用正在显示对话框时无法响应脚本；此时 LivePDF 会提示应用没有响应，并保留上次有效的幻灯片。默认先尝试 PowerPoint，再尝试 Keynote；调整顺序和超时的方法见 README。

### 验证与签名

在开发机上使用 Microsoft PowerPoint 16.114：应用的转换器把含中文的三页 `.pptx` 导出为文字一致的三页 PDF；保存修改后的文件会让运行中的应用重新转换。尚未目视检查演示文稿窗口。Keynote 备用路径未经实测，应视为未验证。Markdown 和 PDF 的行为与 1.1.0 相同；自动化测试覆盖文件类型识别、拒绝未写完的文件、转换应用顺序和错误分类。

app 使用 ad-hoc 完整性签名，安装包没有 Developer ID 签名或 Apple 公证。仍需在另一台目标 Mac 确认安装和首次启动；尚未在另一台 macOS 14 设备上实测本版。

详细操作见[使用指南](https://github.com/noahcui/LivePDF/blob/v1.2.0/README.md#使用)和 [PowerPoint 说明](https://github.com/noahcui/LivePDF/blob/v1.2.0/README.md#powerpoint-演示文稿120)。

---

[Changelog / 更新记录](https://github.com/noahcui/LivePDF/blob/v1.2.0/CHANGELOG.md) · [MIT License / 许可证](https://github.com/noahcui/LivePDF/blob/v1.2.0/LICENSE)
