# LivePDF 1.1.0

A native macOS PDF and Markdown reader that reloads changed files and preserves your reading position when possible.

macOS 原生 PDF 与 Markdown 阅读器，文件更新后自动重载，并尽量保留阅读位置。

**Apple Silicon · macOS 14+ · English / 简体中文**

[English](#english) · [简体中文](#简体中文)

## Downloads / 下载

Download the installer, source snapshot, and checksum file from this release.

本版提供安装包、源码快照和校验清单。

| File / 文件 | Purpose / 用途 |
| --- | --- |
| [LivePDF-1.1.0-arm64.pkg](https://github.com/noahcui/LivePDF/releases/download/v1.1.0/LivePDF-1.1.0-arm64.pkg) | macOS installer / 安装包 |
| [LivePDF-1.1.0-source.zip](https://github.com/noahcui/LivePDF/releases/download/v1.1.0/LivePDF-1.1.0-source.zip) | Source snapshot / 源码快照 |
| [SHA256SUMS-v1.1.0.txt](https://github.com/noahcui/LivePDF/releases/download/v1.1.0/SHA256SUMS-v1.1.0.txt) | SHA-256 checksums / 文件校验清单 |

### Verify files / 校验文件

Place all three files in the same directory, then run the following command. Both the installer and source archive are listed in the checksum file.

将上述三个文件放在同一目录后运行以下命令；清单会同时校验安装包和源码包。

```sh
shasum -a 256 -c SHA256SUMS-v1.1.0.txt
```

## English

### What’s new

- Added Markdown live preview alongside PDF windows. Saving in TextEdit or another editor automatically updates the preview, keeping zoom and preserving the reading position when possible.
- Added headings, emphasis, code, quotes, lists, task lists, tables, links, local images, and system light/dark appearance.
- Added Markdown search with next/previous matches and clearing, plus relative Markdown/PDF links that open in LivePDF.
- Support `.md`, `.markdown`, `.mdown`, and `.mkd` files through the open panel, Finder, drag and drop, and the command line, with English and Simplified Chinese UI.

### Install and open

Open `LivePDF-1.1.0-arm64.pkg` and follow the installer. Administrator approval is required. It installs the app at `/Applications/LivePDF.app` and the command at `/usr/local/bin/livepdf`. An Apple Silicon Mac running macOS 14 or later is required. Running the installed app requires no developer tools or TeX.

Launch LivePDF from Applications, use Finder’s **Open With** menu, or run:

```sh
livepdf paper.pdf "notes with spaces.md"
```

If `/usr/local/bin` is absent from your PATH, use `/usr/local/bin/livepdf` directly. PDF and Markdown documents can remain open together in separate windows.

### Markdown scope

Markdown files must use UTF-8. The renderer supports an offline subset of Markdown rather than complete CommonMark/GFM. Raw HTML is displayed as text; scripts, remote images, math rendering, and Mermaid diagrams are not supported. Local images and relative document links must stay within the Markdown file’s folder or its subfolders. Images refresh when the Markdown reloads; changing an image alone does not trigger a reload.

### Validation and signing

GUI acceptance used the actual LivePDF and TextEdit windows: saving changes triggered preview updates; inserting text earlier in the document preserved the reading position and zoom. Search, next/previous matches, clearing the selection, Chinese filenames containing spaces, local images, tables, task lists, relative Markdown/PDF links, and PDF page navigation were checked through the interface.

The app has an ad-hoc integrity signature. The installer is not Developer ID signed or Apple notarized. Installation and first launch on another target Mac remain to be confirmed; this release has not been tested on a separate macOS 14 machine.

See the [usage guide](https://github.com/noahcui/LivePDF/blob/v1.1.0/README.md#use) and [Markdown preview details](https://github.com/noahcui/LivePDF/blob/v1.1.0/README.md#markdown-live-preview-110) for details.

## 简体中文

### 本版更新

- 新增 Markdown 实时预览，可与 PDF 窗口同时使用。在文本编辑或其他编辑器中保存后自动更新，保留缩放，并尽量保持阅读位置。
- 支持标题、强调、代码、引用、列表、任务列表、表格、链接、本地图片，以及系统深浅色外观。
- 新增 Markdown 搜索、前后匹配和清除选中；文档内的相对 Markdown/PDF 链接可在 LivePDF 中打开。
- 通过打开面板、Finder、拖放和命令行打开 `.md`、`.markdown`、`.mdown`、`.mkd` 文件，提供英语与简体中文界面。

### 安装与打开

双击 `LivePDF-1.1.0-arm64.pkg`，按安装器提示操作，需要管理员授权。应用安装到 `/Applications/LivePDF.app`，命令安装到 `/usr/local/bin/livepdf`。需要 Apple Silicon Mac 和 macOS 14 或更新版本；运行已安装的应用无需开发工具或 TeX。

从“应用程序”启动 LivePDF，在 Finder 的“打开方式”中选择它，或运行：

```sh
livepdf paper.pdf "有 空格的笔记.md"
```

如果 PATH 不含 `/usr/local/bin`，可直接使用 `/usr/local/bin/livepdf`。PDF 和 Markdown 可以分别在多个窗口中同时阅读。

### Markdown 支持范围

Markdown 文件须使用 UTF-8 编码。渲染器提供离线 Markdown 常用语法子集，未完整实现 CommonMark/GFM。原始 HTML 按文本显示，不支持脚本、远程图片、数学公式渲染和 Mermaid 图表。本地图片和相对文档链接须位于 Markdown 所在目录或其子目录中。图片随 Markdown 重载而更新；仅修改图片不会触发重载。

### 验证与签名

已在真实 LivePDF 和文本编辑窗口中完成 GUI 验收：修改并保存后预览自动更新，在前文插入内容后阅读位置和缩放保持。通过界面核查了搜索、前后匹配、清除选中、含空格的中文文件名、本地图片、表格、任务列表、相对 Markdown/PDF 链接，以及 PDF 跳页。

app 使用 ad-hoc 完整性签名，安装包没有 Developer ID 签名或 Apple 公证。仍需在另一台目标 Mac 确认安装和首次启动；尚未在另一台 macOS 14 设备上实测本版。

详细操作见[使用指南](https://github.com/noahcui/LivePDF/blob/v1.1.0/README.md#使用)和 [Markdown 预览说明](https://github.com/noahcui/LivePDF/blob/v1.1.0/README.md#markdown-实时预览110)。

---

[Changelog / 更新记录](https://github.com/noahcui/LivePDF/blob/v1.1.0/CHANGELOG.md) · [MIT License / 许可证](https://github.com/noahcui/LivePDF/blob/v1.1.0/LICENSE)
