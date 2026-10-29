import AppKit
import UniformTypeIdentifiers
import LivePDFCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var documents: [URL: NSWindowController & LiveDocumentWindow] = [:]
    private var welcome: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu()
        // LaunchServices supplies Finder / `open` URLs through application(_:open:).
        // Also support running the executable directly from a terminal.
        let paths = commandLineFilePaths()
        if !paths.isEmpty {
            open(urls: paths.map { URL(fileURLWithPath: $0) })
        }
        if documents.isEmpty { showWelcome() }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        open(urls: urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWelcome() }
        return true
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = DocumentKind.contentTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { open(urls: panel.urls) }
    }

    func open(urls: [URL]) {
        for rawURL in urls where rawURL.isFileURL {
            // Keep the original path: symlink/rename writes must continue watching that path.
            let url = rawURL.standardizedFileURL
            guard let kind = DocumentKind(url: url) else { continue }
            if let existing = documents[url] {
                existing.showWindow(nil)
                existing.window?.makeKeyAndOrderFront(nil)
                continue
            }
            let controller: NSWindowController & LiveDocumentWindow
            switch kind {
            case .pdf: controller = DocumentWindowController(fileURL: url)
            case .markdown: controller = MarkdownWindowController(fileURL: url)
            }
            controller.onOpenURLs = { [weak self] in self?.open(urls: $0) }
            controller.onClose = { [weak self] in self?.documents.removeValue(forKey: url) }
            documents[url] = controller
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            controller.start()
        }
        if !documents.isEmpty {
            welcome?.close()
            welcome = nil
        }
    }

    private func showWelcome() {
        if welcome == nil {
            welcome = WelcomeWindowController()
            welcome?.onOpenURLs = { [weak self] in self?.open(urls: $0) }
        }
        welcome?.showWindow(nil)
        welcome?.window?.makeKeyAndOrderFront(nil)
    }

    private func commandLineFilePaths() -> [String] {
        var arguments = CommandLine.arguments.dropFirst().makeIterator()
        var paths: [String] = []
        var pathsOnly = false
        while let argument = arguments.next() {
            if pathsOnly {
                paths.append(argument)
            } else if argument == "--" {
                pathsOnly = true
            } else if argument.hasPrefix("-") {
                // Cocoa accepts -AppleLanguages / -AppleLocale and -NS… user
                // defaults followed by a value. Those values are not file paths.
                // Finder's legacy -psn_… launch argument has no following value.
                if !argument.contains("=") &&
                    (argument.hasPrefix("-Apple") || argument.hasPrefix("-NS")) {
                    _ = arguments.next()
                }
            } else {
                paths.append(argument)
            }
        }
        return paths
    }

    private func makeMenu() {
        let main = NSMenu()
        let appMenu = NSMenu(title: "LivePDF")
        appMenu.addItem(withTitle: L10n.text("About LivePDF"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("Hide LivePDF"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: L10n.text("Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L10n.text("Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("Quit LivePDF"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(appMenu, to: main)

        let fileMenu = NSMenu(title: L10n.text("File"))
        let open = fileMenu.addItem(withTitle: L10n.text("Open…"), action: #selector(openDocument(_:)), keyEquivalent: "o")
        open.target = self
        fileMenu.addItem(withTitle: L10n.text("Reload"), action: #selector(DocumentWindowController.reloadDocument(_:)), keyEquivalent: "r")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L10n.text("Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(fileMenu, to: main)

        let editMenu = NSMenu(title: L10n.text("Edit"))
        editMenu.addItem(withTitle: L10n.text("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: L10n.text("Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.text("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.text("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.text("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.text("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.text("Find…"), action: #selector(DocumentWindowController.showSearch(_:)), keyEquivalent: "f")
        editMenu.addItem(withTitle: L10n.text("Find Next"), action: #selector(DocumentWindowController.findNext(_:)), keyEquivalent: "g")
        let previous = editMenu.addItem(withTitle: L10n.text("Find Previous"), action: #selector(DocumentWindowController.findPrevious(_:)), keyEquivalent: "g")
        previous.keyEquivalentModifierMask = [.command, .shift]
        add(editMenu, to: main)

        let viewMenu = NSMenu(title: L10n.text("View"))
        viewMenu.addItem(withTitle: L10n.text("Zoom In"), action: #selector(DocumentWindowController.increaseZoom(_:)), keyEquivalent: "+")
        // Most keyboards send '=' for Command-plus without Shift.
        let alternate = viewMenu.addItem(withTitle: L10n.text("Zoom In"), action: #selector(DocumentWindowController.increaseZoom(_:)), keyEquivalent: "=")
        alternate.isAlternate = true
        viewMenu.addItem(withTitle: L10n.text("Zoom Out"), action: #selector(DocumentWindowController.decreaseZoom(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: L10n.text("Actual Size"), action: #selector(DocumentWindowController.actualSize(_:)), keyEquivalent: "0")
        viewMenu.addItem(withTitle: L10n.text("Fit Width"), action: #selector(DocumentWindowController.fitWidth(_:)), keyEquivalent: "9")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: L10n.text("Continuous Scroll"), action: #selector(DocumentWindowController.continuousMode(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: L10n.text("Single Page"), action: #selector(DocumentWindowController.singlePageMode(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: L10n.text("Two Pages Continuous"), action: #selector(DocumentWindowController.twoPageMode(_:)), keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: L10n.text("Go to Page…"), action: #selector(DocumentWindowController.focusPage(_:)), keyEquivalent: "l")
        add(viewMenu, to: main)

        let windowMenu = NSMenu(title: L10n.text("Window"))
        windowMenu.addItem(withTitle: L10n.text("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L10n.text("Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L10n.text("Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        add(windowMenu, to: main)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = main
    }

    private func add(_ menu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
