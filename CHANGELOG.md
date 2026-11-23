# Changelog

## 1.3.0 — 2026-11-23

- Add **File → Export as PDF…** (⇧⌘E) to every document window. It exports the whole document: PDF and presentation windows save all pages of the PDF on screen, and Markdown windows save a paginated PDF.
- Convert presentations with Microsoft PowerPoint whenever it is installed. Keynote is used only when PowerPoint is not installed, and a PowerPoint failure is no longer retried in Keynote.

## 1.2.0 — 2026-11-22

- Open PowerPoint files (`.pptx`, `.ppt`, `.ppsx`, `.pps`) by exporting them to PDF through an installed Microsoft PowerPoint or Keynote, with live reload and the same position, zoom, search, and navigation as PDF windows.

## 1.1.0 — 2026-10-29

- Add Markdown windows alongside PDFs, with live reload, scroll and zoom preservation, search, local images, and light/dark appearance.
- Support Markdown through Finder, the open panel, the command line, and drag and drop, with English and Simplified Chinese UI.
- Keep Markdown previews offline and escape raw HTML; load local images only within the document directory.
- Clear Markdown search selection when the search query is cleared.


## 1.0.2 — 2026-10-19

- Localize the installer and application in English and Simplified Chinese,
  following the system or per-app language preference with an English fallback.
- Translate menus, welcome text, search, tooltips, reload status, and errors.
- Add regional language selection, fallback, and formatting tests.
- Ignore Cocoa language defaults when interpreting direct-launch file arguments.

## 1.0.1 — 2026-10-19

- Add an original macOS app icon with editable Core Graphics drawing source.
- Add MIT licensing, dependency notices, and contribution guidance; include
  notices in binary distributions.
- Add an app repackaging option for resource-only updates.

## 1.0.0 — 2026-10-19

- Native AppKit / PDFKit reader with one window per PDF.
- Directory FSEvents watching, configurable debounce, immutable PDF snapshots,
  and rejection of incomplete or empty documents.
- Restore page-relative visible position, numerical zoom, and display mode.
- Search, page jump, zoom, Finder opening, drag and drop, and CLI launcher.
- Release app build and transferable arm64 macOS 14+ installer.
- 24 automated tests for file watching, loading, and view-state restoration.
