# Contributing

LivePDF is a small native macOS PDF and Markdown reader focused on reliable reloads without
losing reading position. Contributions should preserve that behavior and keep
the runtime free of third-party dependencies.

Use an Apple Silicon Mac with macOS 14 or later and Swift 6 developer tools:

```sh
./test.sh
./build.sh
```

Tests create PDFKit fixtures without TeX. For changes to watching or position
restoration, include a regression test that exercises the behavior rather than
duplicating the implementation. Use the manual checks in `README.md` for focus,
scrolling, and visual behavior on a real target Mac.

Keep file watching, immutable document loading, rendering, view state, and AppKit window logic
separate. Do not add PDF editing, annotations, cloud services, or SyncTeX to a
small unrelated change. Source navigation has a dedicated protocol for future
work. Markdown uses a dependency-free parser and a persistent WebKit shell. Keep
raw document HTML escaped and local image access confined to its document directory.

Only contribute code and assets you have the right to distribute under the
project's MIT license. Preserve existing copyright notices and describe any
third-party source, asset, or additional license in the change. Review and verify
your changes before submitting them.

Regenerate the original app icon with `./scripts/make-icon.sh`; include both its
editable drawing code and the generated PNG / ICNS when changing its design.

Build installers with `./package.sh`. Installers are not Developer ID signed or
notarized. No signing certificates or credentials belong in the repository.
