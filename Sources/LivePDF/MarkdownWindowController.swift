import AppKit
import WebKit
import LivePDFCore

final class MarkdownWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate {
    let fileURL: URL
    var onOpenURLs: (([URL]) -> Void)?
    var onClose: (() -> Void)?
    private let webView: DropMarkdownWebView
    private let resolver: MarkdownResourceResolver
    private let searchField = NSSearchField()
    private let searchCountLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: L10n.text("Opening…"))
    private let loadQueue = DispatchQueue(label: "LivePDF.markdown-loader", qos: .userInitiated)
    private var watcher: FileWatcher?
    private var watcherWarning: String?
    private var loadGeneration = 0
    private var closed = false
    private var ready = false
    private var pendingBody: String?
    private var lastBody: String?

    init(fileURL: URL) {
        self.fileURL = fileURL
        resolver = MarkdownResourceResolver(documentURL: fileURL)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(MarkdownImageHandler(resolver: resolver), forURLScheme: "livepdf-resource")
        webView = DropMarkdownWebView(frame: .zero, configuration: configuration)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = fileURL.lastPathComponent
        window.representedURL = fileURL
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 360)
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("LivePDF.MarkdownWindow")
        webView.navigationDelegate = self
        webView.onOpenURLs = { [weak self] in self?.onOpenURLs?($0) }
        webView.allowsBackForwardNavigationGestures = false
        buildContent(in: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func start() {
        webView.loadHTMLString(MarkdownPreviewPage.html, baseURL: resolver.baseURL)
        let configured = UserDefaults.standard.double(forKey: "ReloadDebounceInterval")
        let interval = configured.isFinite && configured > 0 ? configured : 0.3
        let watcher = FileWatcher(url: fileURL, debounceInterval: interval, onSnapshot: { [weak self] data in
            DispatchQueue.main.async { [weak self] in self?.requestReload(snapshot: data) }
        })
        self.watcher = watcher
        do { try watcher.start() }
        catch { watcherWarning = L10n.format("Automatic watching is unavailable. Press ⌘R to retry: %@", error.localizedDescription) }
        requestReload()
    }

    private func buildContent(in window: NSWindow) {
        let root = NSView()
        window.contentView = root
        let kind = NSTextField(labelWithString: "Markdown")
        kind.font = .systemFont(ofSize: 13, weight: .semibold)
        let edit = NSButton(title: L10n.text("Open in TextEdit"), target: self, action: #selector(openInEditor(_:)))
        edit.bezelStyle = .rounded
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.placeholderString = L10n.text("Search Markdown (⌘F)")
        searchField.setAccessibilityLabel(L10n.text("Search Markdown (⌘F)"))
        searchField.target = self
        searchField.action = #selector(findNext(_:))
        searchField.sendsWholeSearchString = true
        searchField.sendsSearchStringImmediately = false
        searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
        searchField.widthAnchor.constraint(lessThanOrEqualToConstant: 360).isActive = true
        let previous = NSButton(title: "‹", target: self, action: #selector(findPrevious(_:)))
        previous.setAccessibilityLabel(L10n.text("Previous search result"))
        previous.toolTip = L10n.text("Previous search result (⇧⌘G)")
        let next = NSButton(title: "›", target: self, action: #selector(findNext(_:)))
        next.setAccessibilityLabel(L10n.text("Next search result"))
        next.toolTip = L10n.text("Next search result (⌘G)")
        previous.bezelStyle = .rounded
        next.bezelStyle = .rounded
        searchCountLabel.font = .systemFont(ofSize: 11)
        searchCountLabel.textColor = .secondaryLabelColor
        let header = NSStackView(views: [kind, edit, spacer, searchField, previous, next, searchCountLabel])
        header.orientation = .horizontal
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for view in [header, webView, statusLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.topAnchor.constraint(equalTo: header.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -5),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -5),
            statusLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    @objc private func openInEditor(_ sender: Any?) {
        guard let editor = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else { return }
        NSWorkspace.shared.open([fileURL], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc func reloadDocument(_ sender: Any?) {
        if watcherWarning != nil, let watcher {
            do { try watcher.start(); watcherWarning = nil }
            catch { watcherWarning = L10n.format("Automatic watching is unavailable: %@", error.localizedDescription) }
        }
        if !ready { webView.loadHTMLString(MarkdownPreviewPage.html, baseURL: resolver.baseURL) }
        requestReload()
    }

    private func requestReload(snapshot: Data? = nil) {
        guard !closed else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let url = fileURL
        loadQueue.async { [weak self] in
            let result = Result {
                let source = try snapshot.map { try MarkdownDocumentLoader.load(data: $0) } ?? MarkdownDocumentLoader.load(url: url)
                return MarkdownRenderer.render(source)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.closed, generation == self.loadGeneration else { return }
                switch result {
                case .success(let body):
                    self.pendingBody = body
                    self.renderPendingBody()
                case .failure(let error):
                    let prefix = self.lastBody == nil
                        ? L10n.text("Unable to open yet. Waiting for a file update, or press ⌘R.")
                        : L10n.text("Keeping the last valid document. Waiting for a file update.")
                    self.setStatus(prefix + " " + error.localizedDescription)
                }
            }
        }
    }

    private func renderPendingBody() {
        guard ready, !closed, let body = pendingBody else { return }
        pendingBody = nil
        let generation = loadGeneration
        webView.callAsyncJavaScript("return window.livePDF.render(body)", arguments: ["body": body], in: nil, in: .page) { [weak self] result in
            guard let self, !self.closed, generation == self.loadGeneration else { return }
            switch result {
            case .success:
                self.lastBody = body
                self.searchCountLabel.stringValue = ""
                let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                self.window?.title = "\(self.fileURL.lastPathComponent) — \(time)"
                self.window?.subtitle = L10n.format("Last loaded %@", time)
                self.setStatus(self.watcherWarning ?? L10n.format("Markdown · %@", self.fileURL.path))
            case .failure:
                self.pendingBody = body
                self.setStatus(L10n.text("Unable to render Markdown. Press ⌘R to retry."))
            }
        }
    }

    private func setStatus(_ text: String) {
        statusLabel.stringValue = text
        statusLabel.toolTip = text
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !closed else { return }
        ready = true
        renderPendingBody()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !closed, (error as NSError).code != NSURLErrorCancelled else { return }
        ready = false
        setStatus(L10n.text("Unable to render Markdown. Press ⌘R to retry."))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !closed else { return }
        ready = false
        pendingBody = pendingBody ?? lastBody
        webView.loadHTMLString(MarkdownPreviewPage.html, baseURL: resolver.baseURL)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.navigationType == .other &&
            (url.absoluteString == "about:blank" || (!ready && url == resolver.baseURL)) {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        guard navigationAction.navigationType == .linkActivated else { return }
        if url.scheme == resolver.baseURL.scheme {
            if url.path == "/", let fragment = url.fragment?.removingPercentEncoding {
                webView.callAsyncJavaScript("document.getElementById(id)?.scrollIntoView()", arguments: ["id": fragment], in: nil, in: .page)
            } else if let local = try? resolver.resolve(url), DocumentKind(url: local) != nil {
                onOpenURLs?([local])
            }
        } else if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showSearch(_ sender: Any?) {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }
    @objc func findNext(_ sender: Any?) { find(backwards: false) }
    @objc func findPrevious(_ sender: Any?) { find(backwards: true) }
    private func find(backwards: Bool) {
        let query = searchField.stringValue
        let generation = loadGeneration
        webView.callAsyncJavaScript("return window.livePDF.find(query, backwards)",
                                    arguments: ["query": query, "backwards": backwards], in: nil, in: .page) { [weak self] result in
            guard let self, !self.closed, self.searchField.stringValue == query else { return }
            guard generation == self.loadGeneration else { return }
            if case .success(let found) = result {
                self.searchCountLabel.stringValue = query.isEmpty || (found as? Bool == true) ? "" : L10n.text("No results")
            }
        }
    }
    @objc func increaseZoom(_ sender: Any?) { webView.pageZoom = min(3, webView.pageZoom * 1.2) }
    @objc func decreaseZoom(_ sender: Any?) { webView.pageZoom = max(0.5, webView.pageZoom / 1.2) }
    @objc func actualSize(_ sender: Any?) {
        webView.pageZoom = 1
        webView.evaluateJavaScript("window.livePDF.actualSize()")
    }
    @objc func fitWidth(_ sender: Any?) {
        webView.pageZoom = 1
        webView.evaluateJavaScript("window.livePDF.fitWidth()")
    }

    func windowWillClose(_ notification: Notification) {
        closed = true
        loadGeneration += 1
        watcher?.stop()
        watcher = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        onClose?()
    }
}

private final class MarkdownImageHandler: NSObject, WKURLSchemeHandler {
    let resolver: MarkdownResourceResolver
    private let queue = DispatchQueue(label: "LivePDF.markdown-images", qos: .userInitiated)
    private var active: [ObjectIdentifier: UUID] = [:]
    init(resolver: MarkdownResourceResolver) { self.resolver = resolver }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(CocoaError(.fileReadInvalidFileName))
            return
        }
        let identifier = ObjectIdentifier(urlSchemeTask)
        let token = UUID()
        active[identifier] = token
        let resolver = self.resolver
        queue.async { [weak self] in
            let result = Result { try resolver.resource(url) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active[identifier] == token else { return }
                self.active.removeValue(forKey: identifier)
                switch result {
                case .success(let resource):
                    urlSchemeTask.didReceive(URLResponse(url: url, mimeType: resource.mimeType,
                                                        expectedContentLength: resource.data.count, textEncodingName: nil))
                    urlSchemeTask.didReceive(resource.data)
                    urlSchemeTask.didFinish()
                case .failure(let error): urlSchemeTask.didFailWithError(error)
                }
            }
        }
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        active.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
    }
}
