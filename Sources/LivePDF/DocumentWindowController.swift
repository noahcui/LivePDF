import AppKit
import PDFKit
import LivePDFCore

final class DocumentWindowController: NSWindowController, NSWindowDelegate {
    let fileURL: URL
    var onOpenURLs: (([URL]) -> Void)?
    var onClose: (() -> Void)?

    private let pdfView = DropPDFView(frame: .zero)
    private let pageField = NSTextField(string: "1")
    private let pageCountLabel = NSTextField(labelWithString: "/ —")
    private let searchField = NSSearchField()
    private let searchCountLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: L10n.text("Opening…"))
    private let loadQueue = DispatchQueue(label: "LivePDF.document-loader", qos: .userInitiated)
    private var watcher: FileWatcher?
    private var loadGeneration = 0
    private var closed = false
    private var watcherWarning: String?
    private var observers: [NSObjectProtocol] = []
    private var searchObservers: [NSObjectProtocol] = []
    private var matches: [PDFSelection] = []
    private var matchIndex = -1
    private var advanceAfterSearch = 0
    private var lastReload: Date?

    init(fileURL: URL) {
        self.fileURL = fileURL
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = fileURL.lastPathComponent
        window.representedURL = fileURL
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 660, height: 360)
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("LivePDF.DocumentWindow")
        buildContent(in: window)
        observers.append(NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: pdfView, queue: .main) { [weak self] _ in
            self?.updatePageIndicator()
        })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func start() {
        let configured = UserDefaults.standard.double(forKey: "ReloadDebounceInterval")
        let interval = configured.isFinite && configured > 0 ? configured : 0.3
        let watcher = FileWatcher(url: fileURL, debounceInterval: interval, onSnapshot: { [weak self] data in
            DispatchQueue.main.async { [weak self] in self?.requestReload(snapshot: data) }
        })
        self.watcher = watcher
        do {
            try watcher.start()
        } catch {
            watcherWarning = L10n.format("Automatic watching is unavailable. Press ⌘R to retry: %@", error.localizedDescription)
        }
        requestReload()
    }

    private func buildContent(in window: NSWindow) {
        let root = NSView()
        window.contentView = root
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = true
        pdfView.minScaleFactor = 0.05
        pdfView.maxScaleFactor = 20
        pdfView.backgroundColor = .underPageBackgroundColor
        pdfView.onOpenURLs = { [weak self] in self?.onOpenURLs?($0) }
        pageField.alignment = .right
        pageField.target = self
        pageField.action = #selector(jumpToPage(_:))
        pageField.toolTip = L10n.text("Enter a page number and press Return (⌘L)")
        pageField.setAccessibilityLabel(L10n.text("Page number"))
        pageField.widthAnchor.constraint(equalToConstant: 52).isActive = true
        pageCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        searchField.placeholderString = L10n.text("Search PDF (⌘F)")
        searchField.target = self
        searchField.action = #selector(search(_:))
        searchField.sendsWholeSearchString = true
        searchField.sendsSearchStringImmediately = false
        searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
        searchField.widthAnchor.constraint(lessThanOrEqualToConstant: 360).isActive = true
        searchField.toolTip = L10n.text("Enter a search term and press Return; ⌘G / ⇧⌘G switches results")
        let previous = NSButton(title: "‹", target: self, action: #selector(findPrevious(_:)))
        previous.toolTip = L10n.text("Previous search result (⇧⌘G)")
        previous.setAccessibilityLabel(L10n.text("Previous search result"))
        let next = NSButton(title: "›", target: self, action: #selector(findNext(_:)))
        next.toolTip = L10n.text("Next search result (⌘G)")
        next.setAccessibilityLabel(L10n.text("Next search result"))
        previous.bezelStyle = .rounded
        next.bezelStyle = .rounded
        searchCountLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        searchCountLabel.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [NSTextField(labelWithString: L10n.text("Page")), pageField, pageCountLabel, spacer, searchField, previous, next, searchCountLabel])
        header.orientation = .horizontal
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for view in [header, pdfView, statusLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: header.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -5),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -5),
            statusLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    @objc func reloadDocument(_ sender: Any?) {
        if watcherWarning != nil, let watcher {
            do {
                try watcher.start()
                watcherWarning = nil
            } catch {
                watcherWarning = L10n.format("Automatic watching is unavailable: %@", error.localizedDescription)
            }
        }
        requestReload()
    }

    private func requestReload(snapshot: Data? = nil) {
        guard !closed else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let url = fileURL
        // Parsing never touches the displayed document or PDFView. Each result
        // owns an immutable byte snapshot, so in-place writes cannot corrupt it.
        loadQueue.async { [weak self] in
            let result = Result {
                try snapshot.map { try PDFDocumentLoader.load(data: $0) } ?? PDFDocumentLoader.load(url: url)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.closed, self.loadGeneration == generation else { return }
                switch result {
                case .success(let document): self.replaceDocument(with: document)
                case .failure(let error):
                    let prefix = self.pdfView.document == nil
                        ? L10n.text("Unable to open yet. Waiting for a file update, or press ⌘R.")
                        : L10n.text("Keeping the last valid document. Waiting for a file update.")
                    self.statusLabel.stringValue = prefix + " " + error.localizedDescription
                    self.statusLabel.toolTip = self.statusLabel.stringValue
                }
            }
        }
    }

    private func replaceDocument(with document: PDFDocument) {
        guard document.pageCount > 0 else { return }
        // Capture at commit time, since the user may scroll while parsing.
        let state = PDFViewStateAdapter.capture(from: pdfView)
        let responder = window?.firstResponder
        stopSearch()
        window?.disableScreenUpdatesUntilFlush()
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        NSAnimationContext.current.allowsImplicitAnimation = false
        pdfView.document = document
        if let state {
            PDFViewStateAdapter.restore(state, in: pdfView)
        } else {
            pdfView.autoScales = true
            pdfView.layoutDocumentView()
        }
        NSAnimationContext.endGrouping()
        // Never order/activate the window when a background compilation finishes.
        if let responder, window?.firstResponder !== responder {
            window?.makeFirstResponder(responder)
        }
        let loadedAt = Date()
        lastReload = loadedAt
        let time = Self.timeFormatter.string(from: loadedAt)
        window?.title = "\(fileURL.lastPathComponent) — \(time)"
        window?.subtitle = L10n.format("Last loaded %@", time)
        statusLabel.stringValue = watcherWarning ?? L10n.format("Loaded %ld pages · %@", document.pageCount, fileURL.path)
        statusLabel.toolTip = statusLabel.stringValue
        updatePageIndicator()
        if !searchField.stringValue.isEmpty { beginSearch(advance: 0) }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func updatePageIndicator() {
        guard let document = pdfView.document else { return }
        pageCountLabel.stringValue = "/ \(document.pageCount)"
        // Leave a page number being edited intact.
        if pageField.currentEditor() == nil || window?.firstResponder !== pageField.currentEditor() {
            let page = pdfView.currentPage
            let number = page.map { document.index(for: $0) + 1 } ?? 1
            pageField.stringValue = "\(number)"
            pageCountLabel.setAccessibilityLabel(L10n.format("Page %ld of %ld", number, document.pageCount))
        }
    }

    @objc func focusPage(_ sender: Any?) {
        window?.makeFirstResponder(pageField)
        pageField.selectText(nil)
    }

    @objc private func jumpToPage(_ sender: Any?) {
        guard let document = pdfView.document, let number = Int(pageField.stringValue.trimmingCharacters(in: .whitespaces)), document.pageCount > 0 else {
            window?.makeFirstResponder(pdfView)
            updatePageIndicator()
            return
        }
        if let page = document.page(at: min(max(number - 1, 0), document.pageCount - 1)) { pdfView.go(to: page) }
        window?.makeFirstResponder(pdfView)
        updatePageIndicator()
    }

    @objc func increaseZoom(_ sender: Any?) { setZoom(pdfView.scaleFactor * 1.2) }
    @objc func decreaseZoom(_ sender: Any?) { setZoom(pdfView.scaleFactor / 1.2) }
    @objc func actualSize(_ sender: Any?) { setZoom(1) }

    private func setZoom(_ value: CGFloat) {
        pdfView.autoScales = false
        pdfView.scaleFactor = min(max(value, pdfView.minScaleFactor), pdfView.maxScaleFactor)
    }

    @objc func fitWidth(_ sender: Any?) {
        guard let page = pdfView.currentPage else { return }
        var pageRect = pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
        if pdfView.displayMode == .twoUp || pdfView.displayMode == .twoUpContinuous,
           let document = pdfView.document {
            let index = document.index(for: page)
            // PDFKit supplies the actual spread layout (including book cover).
            for otherIndex in [index - 1, index + 1] where otherIndex >= 0 && otherIndex < document.pageCount {
                guard let other = document.page(at: otherIndex) else { continue }
                let rect = pdfView.convert(other.bounds(for: pdfView.displayBox), from: other)
                if abs(rect.midY - pageRect.midY) < min(rect.height, pageRect.height) / 2 {
                    pageRect = pageRect.union(rect)
                }
            }
        }
        let pageWidth = pageRect.width / max(pdfView.scaleFactor, 0.01)
        let scrollView = pdfView.documentView?.enclosingScrollView
        let availableWidth = (scrollView?.contentView.bounds.width ?? pdfView.bounds.width) - 20
        guard pageWidth > 0, availableWidth > 0 else { return }
        setZoom(availableWidth / pageWidth)
    }

    @objc func continuousMode(_ sender: Any?) { pdfView.displayMode = .singlePageContinuous }
    @objc func singlePageMode(_ sender: Any?) { pdfView.displayMode = .singlePage }
    @objc func twoPageMode(_ sender: Any?) { pdfView.displayMode = .twoUpContinuous }

    @objc func showSearch(_ sender: Any?) {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    @objc private func search(_ sender: Any?) { beginSearch(advance: 1) }

    private func stopSearch() {
        searchObservers.forEach { NotificationCenter.default.removeObserver($0) }
        searchObservers.removeAll()
        pdfView.document?.cancelFindString()
        matches.removeAll()
        matchIndex = -1
        searchCountLabel.stringValue = ""
    }

    private func beginSearch(advance: Int) {
        stopSearch()
        pdfView.highlightedSelections = nil
        let query = searchField.stringValue
        guard !query.isEmpty, let document = pdfView.document else { return }
        advanceAfterSearch = advance
        searchCountLabel.stringValue = L10n.text("Searching…")
        searchObservers.append(NotificationCenter.default.addObserver(forName: .PDFDocumentDidFindMatch, object: document, queue: .main) { [weak self] notification in
            guard let self, let match = notification.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection else { return }
            match.color = .systemYellow.withAlphaComponent(0.4)
            self.matches.append(match)
        })
        searchObservers.append(NotificationCenter.default.addObserver(forName: .PDFDocumentDidEndFind, object: document, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.pdfView.highlightedSelections = self.matches
            switch self.matches.count {
            case 0: self.searchCountLabel.stringValue = L10n.text("No results")
            case 1: self.searchCountLabel.stringValue = L10n.text("1 result")
            default: self.searchCountLabel.stringValue = L10n.format("%ld results", self.matches.count)
            }
            if self.advanceAfterSearch != 0 { self.selectMatch(offset: self.advanceAfterSearch) }
        })
        document.beginFindString(query, withOptions: [.caseInsensitive])
    }

    @objc func findNext(_ sender: Any?) {
        if matches.isEmpty { beginSearch(advance: 1) } else { selectMatch(offset: 1) }
    }

    @objc func findPrevious(_ sender: Any?) {
        if matches.isEmpty { beginSearch(advance: -1) } else { selectMatch(offset: -1) }
    }

    private func selectMatch(offset: Int) {
        guard !matches.isEmpty else { return }
        matchIndex = matchIndex < 0 ? (offset > 0 ? 0 : matches.count - 1) : (matchIndex + offset + matches.count) % matches.count
        let match = matches[matchIndex]
        pdfView.setCurrentSelection(match, animate: false)
        pdfView.go(to: match)
        searchCountLabel.stringValue = "\(matchIndex + 1) / \(matches.count)"
    }

    func windowWillClose(_ notification: Notification) {
        closed = true
        loadGeneration += 1
        watcher?.stop()
        watcher = nil
        stopSearch()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        onClose?()
    }
}
