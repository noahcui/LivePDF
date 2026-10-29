# Dependencies and notices

LivePDF's own source code, documentation, and original application icon are
available under the MIT license in `LICENSE`.

The package declares no external Swift Package Manager dependencies. The source
tree does not vendor any third-party library, font, image, or icon collection.

LivePDF uses Apple system frameworks, including AppKit, PDFKit, WebKit, Foundation,
CoreServices, CryptoKit, CoreGraphics, and QuartzCore. They are supplied by macOS
and are not included in the app, installer, or source archive. The MIT license
does not apply to Apple's frameworks, SDK, developer tools, trademarks, or system
fonts. Building the app requires separately licensed Apple developer tools.

The tests use the toolchain's Swift Testing library; it is not included in the
distributed application. This release does not bundle Swift runtime dylibs.
Swift's compiler-output runtime exception is described at
<https://www.swift.org/LICENSE.txt>.

The sample PDF script asks the operating system for Helvetica through Core Text.
No font file or generated sample PDF is included in the app or source archive.

The app icon is drawn from original geometric paths by `scripts/draw-icon.swift`.
It uses no third-party artwork, Apple system images, SF Symbols, or icon font.
