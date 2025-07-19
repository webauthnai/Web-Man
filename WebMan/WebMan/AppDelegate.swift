import Cocoa
import WebKit
import SwiftUI
import LocalAuthentication
import DogTagClient
import UniformTypeIdentifiers

@main
class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var dogTagWindow: NSWindow?
    var addressBar: NSTextField!
    var titleLabel: NSTextField!
    
    // Download management properties
    private var downloadTask: URLSessionDownloadTask?
    private var isDownloading: Bool = false
    private var downloadProgressIndicator: NSProgressIndicator?
    private var downloadStatusLabel: NSTextField?
    
    // New property for the address bar container
    private var addressBarContainer: NSView!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create main window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WebMan Browser"
        window.center()
        
        // Configure window appearance  
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        
        // Create WebView configuration with native WebAuthn bridge
        let config = WebAuthnBrowserSetup.createWebViewConfiguration()
        
        // Create WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // CRITICAL: Use custom UI delegate that handles popups properly
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // Enable web inspector for debugging
        #if DEBUG
        webView.isInspectable = true
        #endif
        
        // Set up unified toolbar and content
        setupUnifiedToolbar()
        
        // Set WebView as main content
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Navigate to test site
        if let url = URL(string: "https://webauthn.me/") {
            webView.load(URLRequest(url: url))
        }
        
        // Force app to foreground
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Create menu bar
        createMenuBar()
        
        // Ensure window is visible
        DispatchQueue.main.async {
            self.window.makeKeyAndOrderFront(nil)
            NSApp.arrangeInFront(nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func setupUnifiedToolbar() {
        // Setup address bar with flexible container for toolbar sizing
        addressBar = NSTextField()
        addressBar.stringValue = "https://webauthn.me/"
        addressBar.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addressBar.bezelStyle = .roundedBezel
        addressBar.focusRingType = .default
        addressBar.target = self
        addressBar.action = #selector(addressBarAction(_:))
        addressBar.placeholderString = "Enter URL..."
        addressBar.isEditable = true
        addressBar.isSelectable = true
        
        // Create a container view for proper toolbar integration
        let addressBarContainer = NSView()
        addressBarContainer.addSubview(addressBar)
        
        // Set up constraints for flexible sizing
        addressBar.translatesAutoresizingMaskIntoConstraints = false
        addressBarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Pin address bar to container edges
            addressBar.leadingAnchor.constraint(equalTo: addressBarContainer.leadingAnchor),
            addressBar.trailingAnchor.constraint(equalTo: addressBarContainer.trailingAnchor),
            addressBar.topAnchor.constraint(equalTo: addressBarContainer.topAnchor),
            addressBar.bottomAnchor.constraint(equalTo: addressBarContainer.bottomAnchor),
            
            // Set container height
            addressBarContainer.heightAnchor.constraint(equalToConstant: 24),
            
            // Set flexible width constraints
            addressBarContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            addressBarContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 10000).withPriority(.init(250))
        ])
        
        // Store the container as our address bar reference for the toolbar
        self.addressBarContainer = addressBarContainer
        
        // Create title label
        titleLabel = NSTextField(labelWithString: "WebMan - Native WebAuthn Browser")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = NSColor.clear
        
        // Create and configure toolbar
        let toolbar = NSToolbar(identifier: "UnifiedToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        
        window.toolbar = toolbar
    }
    
    @objc private func addressBarAction(_ sender: NSTextField) {
        let urlString = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        navigateToURL(urlString)
    }
    
    private func navigateToURL(_ urlString: String) {
        var finalURL = urlString
        
        // Add https:// if no protocol is specified
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            finalURL = "https://" + urlString
        }
        
        if let url = URL(string: finalURL) {
            webView.load(URLRequest(url: url))
        }
    }
    
    private func updateAddressBar(with url: String) {
        DispatchQueue.main.async {
            self.addressBar.stringValue = url
        }
    }
    
    private func updateTitle(with title: String) {
        DispatchQueue.main.async {
            let displayTitle = title.isEmpty ? "WebMan - Native WebAuthn Browser" : title
            self.titleLabel.stringValue = displayTitle
            self.window.title = displayTitle
        }
    }
    

    
    private func createMenuBar() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        
        appMenu.addItem(NSMenuItem(title: "About WebMan", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit WebMan", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        
        viewMenu.addItem(NSMenuItem(title: "Reload", action: #selector(reloadWebView), keyEquivalent: "r"))
        
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        // Credentials Menu
        let credentialsMenuItem = NSMenuItem()
        let credentialsMenu = NSMenu(title: "Credentials")
        
        credentialsMenu.addItem(NSMenuItem(title: "DogTag Manager", action: #selector(showDogTagManager), keyEquivalent: "k"))
        credentialsMenu.addItem(NSMenuItem.separator())
        credentialsMenu.addItem(NSMenuItem(title: "Test Touch ID Authentication", action: #selector(testTouchIDAuthentication), keyEquivalent: "t"))
        credentialsMenu.addItem(NSMenuItem(title: "Show Touch ID Dialog", action: #selector(testTouchIDSheet), keyEquivalent: ""))
        credentialsMenu.addItem(NSMenuItem(title: "Check Biometric Availability", action: #selector(checkBiometricAvailability), keyEquivalent: ""))
        credentialsMenu.addItem(NSMenuItem.separator())
        credentialsMenu.addItem(NSMenuItem(title: "Manage WebAuthn Credentials", action: #selector(diagnoseCredentials), keyEquivalent: "d"))
        
        credentialsMenuItem.submenu = credentialsMenu
        mainMenu.addItem(credentialsMenuItem)
        
        // Debug Menu
        let debugMenuItem = NSMenuItem()
        let debugMenu = NSMenu(title: "Debug")
        
        debugMenu.addItem(NSMenuItem(title: "Open Developer Tools", action: #selector(openDeveloperTools), keyEquivalent: "i"))
        debugMenu.addItem(NSMenuItem.separator())
        debugMenu.addItem(NSMenuItem(title: "Test Database Functionality", action: #selector(testDatabase), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Clean Database Files", action: #selector(cleanDatabase), keyEquivalent: ""))

        
        debugMenuItem.submenu = debugMenu
        mainMenu.addItem(debugMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Menu Actions
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WebMan"
        alert.informativeText = "WebAuthn Client Application\nVersion 1.0"
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @objc private func reloadWebView() {
        webView?.reload()
    }
    
    @objc private func goBack() {
        webView?.goBack()
    }
    
    @objc private func goForward() {
        webView?.goForward()
    }
    
    @objc private func openDeveloperTools() {
        #if DEBUG
        if let webView = webView {
            // Enable developer extras if not already enabled
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
            webView.isInspectable = true
            
            // Trigger inspector
            webView.evaluateJavaScript("console.log('Web Inspector triggered');") { _, _ in
                print("🔧 Web Inspector should now be available")
            }
        }
        #endif
    }
    
    @objc private func diagnoseCredentials() {
        print("🔍 Manual credential diagnostic triggered")
        LocalAuthService.shared.diagnoseCredentialAvailability(for: "https://webauthn.me/")
    }
    
    @objc private func testDatabase() {
        print("🧪 Manual database test triggered")
        let success = LocalAuthService.shared.testDatabaseFunctionality()
        
        let alert = NSAlert()
        alert.messageText = "Database Test"
        alert.informativeText = success ? "Database test passed successfully!" : "Database test failed. Check the console for details."
        alert.alertStyle = success ? .informational : .warning
        alert.runModal()
    }
    
    @objc private func cleanDatabase() {
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "Clean Database Files"
        confirmAlert.informativeText = "This will backup and remove all WebAuthn database files. You'll need to restart the app afterwards. Continue?"
        confirmAlert.alertStyle = .warning
        confirmAlert.addButton(withTitle: "Clean Database")
        confirmAlert.addButton(withTitle: "Cancel")
        
        let response = confirmAlert.runModal()
        if response == .alertFirstButtonReturn {
            print("🧹 Manual database cleanup triggered")
            LocalAuthService.shared.cleanupDatabase()
            
            let successAlert = NSAlert()
            successAlert.messageText = "Database Cleaned"
            successAlert.informativeText = "Database files have been backed up and removed. Please restart the app to recreate the databases."
            successAlert.alertStyle = .informational
            successAlert.runModal()
        }
    }
    

    
    @objc private func testTouchIDAuthentication() {
        print("🔐 Testing Touch ID Authentication directly")
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let alert = NSAlert()
            alert.messageText = "Touch ID Not Available"
            alert.informativeText = error?.localizedDescription ?? "Biometric authentication is not available on this device."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                              localizedReason: "Authenticate with Touch ID for WebMan test") { success, error in
            DispatchQueue.main.async {
                let alert = NSAlert()
                if success {
                    alert.messageText = "Touch ID Success"
                    alert.informativeText = "Biometric authentication succeeded!"
                    alert.alertStyle = .informational
                    print("✅ Touch ID authentication succeeded! ;)")
                } else {
                    alert.messageText = "Touch ID Failed"
                    alert.informativeText = error?.localizedDescription ?? "Authentication failed"
                    alert.alertStyle = .warning
                    print("❌ Touch ID authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                alert.runModal()
            }
        }
    }
    
    @objc private func checkBiometricAvailability() {
        print("🔍 Checking biometric availability")
        
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        let alert = NSAlert()
        alert.messageText = "Biometric Status"
        
        if canEvaluate {
            // Check what type of biometrics are available
            let biometryType = context.biometryType
            var biometryName = "Unknown"
            
            switch biometryType {
            case .none:
                biometryName = "None"
            case .touchID:
                biometryName = "Touch ID"
            case .faceID:
                biometryName = "Face ID"
            case .opticID:
                biometryName = "Optic ID"
            @unknown default:
                biometryName = "Unknown biometric type"
            }
            
            alert.informativeText = "✅ Biometric authentication is available\nType: \(biometryName)"
            alert.alertStyle = .informational
        } else {
            alert.informativeText = "❌ Biometric authentication is not available\nReason: \(error?.localizedDescription ?? "Unknown error")"
            alert.alertStyle = .warning
        }
        
        alert.runModal()
    }

    @objc private func testTouchIDSheet() {
        print("🔐 Testing Touch ID Sheet")
        
        // Show the Touch ID sheet directly without extra background window
        if let mainWindow = NSApp.mainWindow, let contentView = mainWindow.contentView {
            var hostingView: NSHostingView<TouchIDSignInSheet>?
            
            let touchIDSheet = TouchIDSignInSheet(
                siteName: "https://webauthn.me/",
                credentialName: "Test Credential",
                onContinue: {
                    print("✅ Touch ID authentication succeeded! ;)")
                },
                onCancel: {
                    print("❌ Touch ID authentication cancelled")
                },
                onDismiss: {
                    print("🔐 Dismissing Touch ID sheet")
                    hostingView?.removeFromSuperview()
                    hostingView = nil
                }
            )
            
            // Create a hosting view that fills the content area
            hostingView = NSHostingView(rootView: touchIDSheet)
            hostingView!.frame = contentView.bounds
            hostingView!.autoresizingMask = [.width, .height]
            
            // Add directly to the main window's content view
            contentView.addSubview(hostingView!)
        }
    }
    
    @objc private func showWebInspector() {
        #if DEBUG
        if let webView = webView {
            // Enable developer extras if not already enabled
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
            webView.isInspectable = true
            
            // Trigger inspector
            webView.evaluateJavaScript("console.log('Web Inspector triggered');") { _, _ in
                print("🔧 Web Inspector should now be available")
            }
        }
        #endif
    }
    
    @objc private func reloadPage() {
        webView?.reload()
    }
    
    @objc private func showDogTagManager() {
        // If window already exists, just bring it to front
        if let existingWindow = dogTagWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Try a basic AppKit approach first
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "DogTag Manager"
        window.center()
        
        // CRITICAL: Set releasedWhenClosed to false to prevent crash
        // This conflicts with ARC in Swift and causes double-release crash
        window.isReleasedWhenClosed = false
        
        // Set up the real SwiftUI DogTagManager content
        let hostingView = NSHostingView(rootView: DogTagManager())
        window.contentView = hostingView
        
        // Simple cleanup using notification
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.dogTagWindow = nil
        print("🏷️ DogTag Manager window closed")
        }
        
        self.dogTagWindow = window
        window.makeKeyAndOrderFront(nil)
        
        print("🏷️ DogTag Manager window opened")
    }
}

// MARK: - Window Management
// Using SwiftUI native window management - no custom delegates needed

// MARK: - NSToolbarDelegate
extension AppDelegate: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        
        switch itemIdentifier {
        case .backButton:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Go Back"
            item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
            item.target = self
            item.action = #selector(goBack)
            return item
            
        case .forwardButton:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Go Forward"
            item.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
            item.target = self
            item.action = #selector(goForward)
            return item
            
        case .addressBar:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = addressBarContainer
            // Sizing is now handled by Auto Layout constraints on the container view
            return item
            
        case .pageTitle:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = titleLabel
            return item
            
        case .reload:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Reload the current page"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
            item.image?.size = NSSize(width: 36, height: 24)
            item.target = self
            item.action = #selector(reloadWebView)
            return item
            
        case .dogTagManager:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Manage WebAuthn Credentials"
            item.image = NSImage(systemSymbolName: "person.badge.key", accessibilityDescription: "DogTag Manager")
            item.image?.size = NSSize(width: 36, height: 24)
            item.target = self
            item.action = #selector(showDogTagManager)
            return item
            
        default:
            return nil
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .backButton,
            .forwardButton,
            .addressBar,
            .reload,
            .dogTagManager,
            .flexibleSpace,
            .pageTitle,

        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .backButton,
            .forwardButton,
            .addressBar,
            .reload,
            .dogTagManager,
            .flexibleSpace,
            .pageTitle,
        ]
    }
}

// MARK: - Toolbar Item Identifiers
extension NSToolbarItem.Identifier {
    static let backButton = NSToolbarItem.Identifier("BackButton")
    static let forwardButton = NSToolbarItem.Identifier("ForwardButton")
    static let addressBar = NSToolbarItem.Identifier("AddressBar")
    static let pageTitle = NSToolbarItem.Identifier("PageTitle")
    static let reload = NSToolbarItem.Identifier("Reload")
    static let dogTagManager = NSToolbarItem.Identifier("DogTagManager")
}

// MARK: - DogTag Window
class DogTagWindow: NSWindow {
    weak var appDelegate: AppDelegate?
    private var hostingView: NSView?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "DogTag Manager"
        self.center()
        
        // Set self as delegate first
        self.delegate = self
        
        // Get reference to app delegate
        self.appDelegate = NSApp.delegate as? AppDelegate
        
        // Set up the SwiftUI content with proper cleanup
        setupSwiftUIContent()
    }
    
    private func setupSwiftUIContent() {
        // Create the hosting view with DogTagManager
        let hostingView = NSHostingView(rootView: DogTagManager())
        self.hostingView = hostingView
        self.contentView = hostingView
    }
    
    private func cleanupSwiftUIContent() {
        // Clear the hosting view before window closes
        self.contentView = nil
        self.hostingView = nil
    }
    
    deinit {
        print("🏷️ DogTagWindow deallocated")
        cleanupSwiftUIContent()
    }
}

extension DogTagWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("🏷️ DogTag Manager window should close")
        // Clean up SwiftUI content before closing
        cleanupSwiftUIContent()
        appDelegate?.dogTagWindow = nil
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        print("🏷️ DogTag Manager window will close")
        // Final cleanup
        cleanupSwiftUIContent()
        appDelegate?.dogTagWindow = nil
    }
}

// MARK: - WKNavigationDelegate
extension AppDelegate: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            updateAddressBar(with: url.absoluteString)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            updateAddressBar(with: url.absoluteString)
        }
        
        if let title = webView.title, !title.isEmpty {
            updateTitle(with: title)
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url {
            updateAddressBar(with: url.absoluteString)
        }
    }
    
    // CRITICAL: Allow navigation actions (link clicks)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("🚨🚨🚨 APPDELEGATE NAVIGATION ACTION CALLED 🚨🚨🚨")
        print("🔗 Navigation action requested in AppDelegate:")
        print("   - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("   - Navigation type: \(navigationAction.navigationType.rawValue)")
        print("   - Navigation type name: \(navigationTypeName(navigationAction.navigationType))")
        print("   - Target frame: \(String(describing: navigationAction.targetFrame?.isMainFrame))")
        print("   - Source frame: \(String(describing: navigationAction.sourceFrame.isMainFrame))")
        
        // Allow all navigation actions (including link clicks)
        decisionHandler(.allow)
        print("✅ Navigation ALLOWED by AppDelegate")
    }
    
    // Handle downloads - SECURITY FIX: Only download files explicitly marked for download
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let response = navigationResponse.response as? HTTPURLResponse,
              let url = response.url else {
            decisionHandler(.allow)
            return
        }
        
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let urlString = url.absoluteString.lowercased()
        
        // SECURITY FIX: Only trigger downloads for files explicitly marked for download
        // Images, videos, CSS, JS should NEVER auto-download unless Content-Disposition says so
        let isExplicitDownload = contentDisposition.lowercased().contains("attachment")
        
        // Only download binary files that are not web content
        let isBinaryDownload = !isExplicitDownload && (
            contentType == "application/octet-stream" ||
            contentType.hasPrefix("application/zip") ||
            contentType.hasPrefix("application/pdf") ||
            contentType.hasPrefix("application/msword") ||
            contentType.hasPrefix("application/vnd.") ||
            (contentType.hasPrefix("application/") && 
             !contentType.contains("javascript") && 
             !contentType.contains("json") && 
             !contentType.contains("xml"))
        )
        
        if isExplicitDownload || isBinaryDownload {
            // Only log actual downloads, not every image/video
            if isExplicitDownload {
                print("📥 Explicit download detected (Content-Disposition: attachment): \(url.lastPathComponent)")
            } else {
                print("📥 Binary file download detected: \(url.lastPathComponent)")
            }
            handleDownload(from: url)
            decisionHandler(.cancel)
        } else {
            // Allow all web content (images, videos, audio, CSS, JS, HTML) to display inline
            if contentType.hasPrefix("image/") || contentType.hasPrefix("video/") || contentType.hasPrefix("audio/") {
                print("🖼️ ✅ ALLOWING INLINE MEDIA: \(url.lastPathComponent) (\(contentType))")
            }
            decisionHandler(.allow)
        }
    }
    
    private func handleDownload(from url: URL) {
        // Get the filename from URL
        let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = filename
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = true
        
        // Show save panel
        savePanel.begin { result in
            if result == .OK, let saveURL = savePanel.url {
                self.downloadFile(from: url, to: saveURL)
            }
        }
    }
    
    private func downloadFile(from sourceURL: URL, to destinationURL: URL) {
        isDownloading = true
        showDownloadProgress()
        
        // Create download task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: sourceURL)
        downloadTask?.resume()
        
        // Store destination URL for later use
        UserDefaults.standard.set(destinationURL.path, forKey: "downloadDestination")
    }
    
    private func showDownloadProgress() {
        // Add download progress indicator to the toolbar if it doesn't exist
        if downloadProgressIndicator == nil {
            downloadProgressIndicator = NSProgressIndicator()
            downloadProgressIndicator?.style = .bar
            downloadProgressIndicator?.isIndeterminate = false
            downloadProgressIndicator?.minValue = 0.0
            downloadProgressIndicator?.maxValue = 1.0
            downloadProgressIndicator?.doubleValue = 0.0
            
            downloadStatusLabel = NSTextField(labelWithString: "Downloading...")
            downloadStatusLabel?.font = NSFont.systemFont(ofSize: 11)
            downloadStatusLabel?.textColor = NSColor.secondaryLabelColor
            
            // You can add these to the toolbar if needed
            // For now, we'll just update the window title
            window?.title = "WebMan Browser2 - Downloading..."
        }
        
        downloadProgressIndicator?.startAnimation(nil)
    }
    
    private func hideDownloadProgress() {
        downloadProgressIndicator?.stopAnimation(nil)
        downloadProgressIndicator?.doubleValue = 0.0
        downloadStatusLabel?.stringValue = ""
        window?.title = "WebMan Browser2"
    }
    
    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        hideDownloadProgress()
    }
    
    private func navigationTypeName(_ type: WKNavigationType) -> String {
        switch type {
        case .linkActivated: return "LINK_ACTIVATED"
        case .formSubmitted: return "FORM_SUBMITTED"
        case .backForward: return "BACK_FORWARD"
        case .reload: return "RELOAD"
        case .formResubmitted: return "FORM_RESUBMITTED"
        case .other: return "OTHER"
        @unknown default: return "UNKNOWN"
        }
    }
}

// MARK: - WKUIDelegate  
extension AppDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        print("🚨 POPUP/NEW WINDOW REQUEST INTERCEPTED! 🚨")
        print("🔗 Popup URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("🔗 Target frame: \(String(describing: navigationAction.targetFrame))")
        
        // CRITICAL FIX: Instead of creating a new window, load the URL in the main WebView
        if navigationAction.targetFrame == nil {
            print("✅ Loading popup URL in main WebView")
            webView.load(navigationAction.request)
        }
        
        // Return nil to prevent creating a new WebView
        return nil
    }
    
    // Handle JavaScript alerts
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Alert"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    // Handle JavaScript confirmations
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirm"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }
    
    // Handle JavaScript prompts
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Input Required"
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            completionHandler(textField.stringValue)
        } else {
            completionHandler(nil)
        }
    }
    
    // Handle file uploads
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        print("📤 File upload requested")
        
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        
        // Note: WKOpenPanelParameters doesn't provide acceptedMIMETypes
        // The web page will validate file types after selection
        
        openPanel.begin { result in
            if result == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension AppDelegate: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgressIndicator?.doubleValue = progress
            let percentage = Int(progress * 100)
            self.window?.title = "WebMan Browser2 - Downloading... \(percentage)%"
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let destinationPath = UserDefaults.standard.string(forKey: "downloadDestination"),
              let destinationURL = URL(string: "file://" + destinationPath) else {
            print("❌ No destination URL found for download")
            return
        }
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move downloaded file to destination
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.isDownloading = false
                self.window?.title = "WebMan Browser2 - Download Complete!"
                self.hideDownloadProgress()
                
                // Show success notification
                let alert = NSAlert()
                alert.messageText = "Download Complete"
                alert.informativeText = "File saved to: \(destinationURL.path)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Show in Finder")
                
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: "")
                }
                
                // Reset title after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.window?.title = "WebMan Browser2"
                }
            }
            
            print("✅ Download completed: \(destinationURL.path)")
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.window?.title = "WebMan Browser2 - Download Failed"
                self.hideDownloadProgress()
                
                let alert = NSAlert()
                alert.messageText = "Download Failed"
                alert.informativeText = "Error: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
                
                // Reset title after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.window?.title = "WebMan Browser2"
                }
            }
            print("❌ Download failed: \(error)")
        }
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "downloadDestination")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.window?.title = "WebMan Browser2 - Download Failed"
                self.hideDownloadProgress()
                
                if !error.localizedDescription.contains("cancelled") {
                    let alert = NSAlert()
                    alert.messageText = "Download Failed"
                    alert.informativeText = "Error: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
                
                // Reset title after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.window?.title = "WebMan Browser2"
                }
            }
            print("❌ Download task failed: \(error)")
        }
    }
}

// MARK: - NSLayoutConstraint Priority Extension
extension NSLayoutConstraint {
    func withPriority(_ priority: NSLayoutConstraint.Priority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

 
