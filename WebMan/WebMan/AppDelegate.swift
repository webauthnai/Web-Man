import Cocoa
import WebKit
import SwiftUI
import LocalAuthentication
import DogTagClient

@main
class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var dogTagWindow: NSWindow?
    var addressBar: NSTextField!
    var titleLabel: DraggableTitleLabel!
    
    // Download management properties
    var downloadTask: URLSessionDownloadTask?
    var isDownloading: Bool = false
    var downloadProgressIndicator: NSProgressIndicator?
    var downloadStatusLabel: NSTextField?
    
    // New property for the address bar container
    var addressBarContainer: NSView!
    
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
        window.titlebarAppearsTransparent = true
        
        // Remove any separator lines
        if window.responds(to: Selector(("setTitlebarSeparatorStyle:"))) {
            window.perform(Selector(("setTitlebarSeparatorStyle:")), with: 0) // None
        }
        
        // Try to change separator color to clear/transparent
        if window.responds(to: Selector(("setTitlebarSeparatorColor:"))) {
            window.perform(Selector(("setTitlebarSeparatorColor:")), with: NSColor.clear)
        }
        
        // Create WebView configuration with native WebAuthn bridge
        let config = WebAuthnBrowserSetup.createWebViewConfiguration()
        
        // Create WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // CRITICAL: Use custom UI delegate that handles popups properly
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // OBSERVE TITLE CHANGES for dynamic title updates
        webView.addObserver(self, forKeyPath: "title", options: [.new], context: nil)
        
        // Enable web inspector for debugging
        #if DEBUG
        webView.isInspectable = true
        #endif
        
        // Set up unified toolbar and content
        setupUnifiedToolbar()
        
        // Set WebView as main content
        window.contentView = webView
        
        // Add favorites bar as titlebar accessory (Safari style)
        setupFavoritesAccessory()
        
       // window.makeKeyAndOrderFront(nil)
       // window.orderFrontRegardless()
        
        // Navigate to test site
        if let url = URL(string: "https://chat.xcf.ai") {
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
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up observers
        webView?.removeObserver(self, forKeyPath: "title")
    }
    
    // MARK: - KVO Observer for Title Changes
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "title", let webView = object as? WKWebView {
            DispatchQueue.main.async {
                let title = webView.title ?? ""
                self.updateTitle(with: title)
            }
        }
    }
    
    func setupUnifiedToolbar() {
        // Setup address bar with flexible container for toolbar sizing
        addressBar = NSTextField()
        addressBar.stringValue = "https://chat.xcf.ai"
        addressBar.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addressBar.bezelStyle = .roundedBezel
        addressBar.focusRingType = .default
        addressBar.target = self
        addressBar.action = #selector(addressBarAction(_:))
        addressBar.placeholderString = "Enter website or search words"
        addressBar.isEditable = true
        addressBar.isSelectable = true
        
        // Create drag link button with SF Symbol
        let dragButton = DraggableEmojiButton(title: "", target: self, action: #selector(dragButtonClicked(_:)))
        
        // Use SF Symbol for link icon
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let linkImage = NSImage(systemSymbolName: "link", accessibilityDescription: "Link")?.withSymbolConfiguration(symbolConfig) {
            linkImage.isTemplate = true
            dragButton.image = linkImage
            dragButton.imagePosition = .imageOnly
        } else {
            // Fallback to emoji if SF Symbol not available
            dragButton.title = "🔗"
        }
        
        dragButton.bezelStyle = .shadowlessSquare
        dragButton.isBordered = false
        dragButton.toolTip = "Drag to add bookmark"
        dragButton.addressBar = addressBar
        
        // Create a container view with address bar + drag button
        let addressBarContainer = NSView()
        addressBarContainer.addSubview(addressBar)
        addressBarContainer.addSubview(dragButton)
        
        // Set up constraints for flexible sizing
        addressBar.translatesAutoresizingMaskIntoConstraints = false
        dragButton.translatesAutoresizingMaskIntoConstraints = false
        addressBarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Drag button on the LEFT
            dragButton.leadingAnchor.constraint(equalTo: addressBarContainer.leadingAnchor),
            dragButton.topAnchor.constraint(equalTo: addressBarContainer.topAnchor),
            dragButton.bottomAnchor.constraint(equalTo: addressBarContainer.bottomAnchor),
            dragButton.widthAnchor.constraint(equalToConstant: 24),
            
            // Address bar takes most space after drag button
            addressBar.leadingAnchor.constraint(equalTo: dragButton.trailingAnchor, constant: 4),
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
        
        // Create DRAGGABLE title label
        titleLabel = DraggableTitleLabel(labelWithString: "WebMan - Native WebAuthn Browser")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = NSColor.clear
        
        // Set up dragging for title
        (titleLabel!).addressBar = addressBar
        
        // Create and configure toolbar
        let toolbar = NSToolbar(identifier: "UnifiedToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        
        // Remove the separator line
        toolbar.showsBaselineSeparator = false
        
        // Try to change toolbar separator color
        if toolbar.responds(to: Selector(("setSeparatorColor:"))) {
            toolbar.perform(Selector(("setSeparatorColor:")), with: NSColor.clear)
        }
        
        window.toolbar = toolbar
    }
    
    func setupFavoritesAccessory() {
        // Create the favorites toolbar view
        let favoritesToolbar = createFavoritesToolbar()
        
        // Create titlebar accessory view controller (Safari style)
        let accessoryVC = NSTitlebarAccessoryViewController()
        accessoryVC.view = favoritesToolbar
        accessoryVC.layoutAttribute = .bottom
        
        // CRITICAL: Hide the automatic separator line like Safari
        if accessoryVC.responds(to: Selector(("setAutomaticSeparatorHidden:"))) {
            accessoryVC.perform(Selector(("setAutomaticSeparatorHidden:")), with: true)
        }
        
        // Add to window titlebar
        window.addTitlebarAccessoryViewController(accessoryVC)
    }
    
    func setupMainContentWithFavorites() {
        // Create main container
        let containerView = NSView()
        
        // Create favorites toolbar
        let favoritesToolbar = createFavoritesToolbar()
        
        // Add both to container
        containerView.addSubview(favoritesToolbar)
        containerView.addSubview(webView)
        
        // Set up constraints
        favoritesToolbar.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set constraint priorities for proper inspector behavior
        let toolbarHeight = favoritesToolbar.heightAnchor.constraint(equalToConstant: 26)
        toolbarHeight.priority = .required - 1  // High but not required
        
        NSLayoutConstraint.activate([
            // Favorites toolbar at top
            favoritesToolbar.topAnchor.constraint(equalTo: containerView.topAnchor),
            favoritesToolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            favoritesToolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toolbarHeight,
            
            // WebView below favorites - flexible for inspector
            webView.topAnchor.constraint(equalTo: favoritesToolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Set container as window content
        window.contentView = containerView
    }
    
    func createFavoritesToolbar() -> NSView {
        let toolbar = FavoritesToolbar()
        toolbar.delegate = self
        toolbar.wantsLayer = true
        
        // Match the toolbar/titlebar background (no background - let system handle it)
        toolbar.layer?.backgroundColor = NSColor.clear.cgColor
        toolbar.layer?.borderWidth = 0
        toolbar.layer?.borderColor = NSColor.clear.cgColor
        
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay  // Ensures no visible scroll bars
        scrollView.automaticallyAdjustsContentInsets = false
        
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        
        // Load favorites from UserDefaults or use default set
        print("🚀 App startup - loading favorites...")
        let favorites = loadFavoritesFromUserDefaults()
        print("🚀 Loaded \(favorites.count) favorites for initial display")
        
        for (name, url) in favorites {
            let button = createFavoriteButton(name: name, url: url)
            stackView.addArrangedSubview(button)
        }
        
        scrollView.documentView = stackView
        
        // Set up stackView constraints for proper horizontal scrolling
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor)
            // Don't constrain trailing OR height - let stackView expand naturally for scrolling
        ])
        
        toolbar.addSubview(scrollView)
        
        // Add trash can for removing bookmarks
        let trashCan = createTrashCan()
        
        // Add link icon for adding favorites
        
        // Create container for favorites, add link, and trash
        let favoritesContainer = NSView()
        favoritesContainer.addSubview(scrollView)
        favoritesContainer.addSubview(trashCan)
        
        // Set up constraints for favorites, add link, and trash layout
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        trashCan.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // ScrollView takes most of the space
            scrollView.topAnchor.constraint(equalTo: favoritesContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: favoritesContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trashCan.leadingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: favoritesContainer.bottomAnchor),
            
          
            
            // Trash can on the right
            trashCan.topAnchor.constraint(equalTo: favoritesContainer.topAnchor),
            trashCan.trailingAnchor.constraint(equalTo: favoritesContainer.trailingAnchor),
            trashCan.bottomAnchor.constraint(equalTo: favoritesContainer.bottomAnchor),
            trashCan.widthAnchor.constraint(equalToConstant: 10)
        ])
        
        toolbar.addSubview(favoritesContainer)
        
        // Store references for drag and drop
        toolbar.stackView = stackView
        toolbar.scrollView = scrollView
        toolbar.trashCan = trashCan
        
        // Set trash can delegate
        trashCan.delegate = self
        
        // Set up constraints for container 
        favoritesContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container fills the toolbar with padding
            favoritesContainer.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 4),
            favoritesContainer.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            favoritesContainer.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            favoritesContainer.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -4)
        ])
        
        // Set fixed height for titlebar accessory
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        return toolbar
    }
   
    @objc func addCurrentPageToFavorites(_ sender: NSButton) {
        // Get current page URL and title from webView
        guard let currentURL = webView.url?.absoluteString,
              !currentURL.isEmpty,
              currentURL != "about:blank" else {
            showTemporaryMessage("❌ No valid page to add")
            return
        }
        
        // Get page title (or use URL if no title)
        let pageTitle = webView.title?.isEmpty == false ? webView.title! : currentURL
        
        // Clean up the title for display
        let cleanTitle = pageTitle.count > 30 ? String(pageTitle.prefix(30)) + "..." : pageTitle
        
        // Add to favorites
        addFavorite(name: cleanTitle, url: currentURL)
    }
    
    @objc func dragButtonClicked(_ sender: NSButton) {
        // Provide feedback that this button is for dragging
        print("🔗 Drag the link icon to add current URL as bookmark")
    }
    
    // MARK: - UserDefaults for Favorites
    
    func saveFavoritesToUserDefaults() {
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else { 
            print("❌ Could not find toolbar/stackView for saving")
            return 
        }
        
        var favoritesData: [[String: String]] = []
        
        for view in stackView.arrangedSubviews {
            if let button = view as? DraggableFavoriteButton,
               let url = button.identifier?.rawValue {
                favoritesData.append([
                    "name": button.title,
                    "url": url
                ])
                print("📦 Adding to save: \(button.title) -> \(url)")
            }
        }
        
        UserDefaults.standard.set(favoritesData, forKey: "WebManFavorites")
        UserDefaults.standard.synchronize() // Force save
        print("💾 Saved \(favoritesData.count) favorites to UserDefaults")
        print("💾 Data: \(favoritesData)")
    }
    
    func loadFavoritesFromUserDefaults() -> [(name: String, url: String)] {
        print("📂 Attempting to load favorites from UserDefaults...")
        
        guard let favoritesData = UserDefaults.standard.array(forKey: "WebManFavorites") as? [[String: String]] else {
            print("📂 No saved favorites found (key doesn't exist or wrong type), using defaults")
            // Save defaults immediately so we have something saved
            let defaults = getDefaultFavorites()
            let defaultsData = defaults.map { ["name": $0.name, "url": $0.url] }
            UserDefaults.standard.set(defaultsData, forKey: "WebManFavorites")
            UserDefaults.standard.synchronize()
            print("📂 Saved default favorites to UserDefaults for next time")
            return defaults
        }
        
        print("📂 Raw data from UserDefaults: \(favoritesData)")
        
        var favorites: [(name: String, url: String)] = []
        for favoriteDict in favoritesData {
            if let name = favoriteDict["name"],
               let url = favoriteDict["url"] {
                favorites.append((name: name, url: url))
                print("📦 Loaded: \(name) -> \(url)")
            } else {
                print("❌ Invalid favorite data: \(favoriteDict)")
            }
        }
        
        print("📂 Successfully loaded \(favorites.count) favorites from UserDefaults")
        return favorites.isEmpty ? getDefaultFavorites() : favorites
    }
    
    func getDefaultFavorites() -> [(name: String, url: String)] {
        return [
            ("💬 chat.xcf.ai", "https://chat.xcf.ai"),
            ("🐙 github/webauthnai", "https://github.com/webauthnai"),
            ("🤖 xcf.ai", "https://xcf.ai"),
            ("🧠 d1f.ai", "https://d1f.ai"),
            ("❄️ codefreeze.ai", "https://codefreeze.ai"),
            ("🚀 superbox64.com", "https://superbox64.com"),
            ("📱 apps.apple.com", "https://apps.apple.com/ba/developer/id1239131660"),
            ("🎮 github/SuperBox64", "https://github.com/SuperBox64?tab=repositories"),
            ("❄️ github/CodeFreezeAI", "https://github.com/orgs/CodeFreezeAI/repositories"),
            ("⭐️ WebAuthn.me", "https://webauthn.me"),
            ("🔐 WebAuthn.io", "https://webauthn.io")
        ]
    }
    
    func findFavoritesToolbar() -> FavoritesToolbar? {
        // Look for favorites toolbar in titlebar accessory views
        for accessory in window.titlebarAccessoryViewControllers {
            if let toolbar = accessory.view as? FavoritesToolbar {
                return toolbar
            }
            
            // Also check subviews in case it's nested
            func findInSubviews(_ view: NSView) -> FavoritesToolbar? {
                if let toolbar = view as? FavoritesToolbar {
                    return toolbar
                }
                for subview in view.subviews {
                    if let found = findInSubviews(subview) {
                        return found
                    }
                }
                return nil
            }
            
            if let found = findInSubviews(accessory.view) {
                return found
            }
        }
        return nil
    }
    
    func createFavoriteButton(name: String, url: String) -> DraggableFavoriteButton {
        let button = DraggableFavoriteButton(title: name, target: self, action: #selector(favoriteTapped(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(url)
        button.bezelStyle = .shadowlessSquare
        button.controlSize = .mini
        button.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        button.wantsLayer = true
        
        // Completely flat styling - NO BUBBLES, NO BACKGROUNDS, NO ROUNDED CORNERS
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 0
        button.contentTintColor = NSColor.controlAccentColor
        button.isBordered = false
        button.focusRingType = .none
        
        // Store URL for drag operations
        button.favoriteURL = url
        button.delegate = self
        
        return button
    }
    
    func createTrashCan() -> TrashCanView {
        let trashCan = TrashCanView()
        trashCan.wantsLayer = true
        trashCan.layer?.backgroundColor = NSColor.clear.cgColor
        
        return trashCan
    }
    
    @objc func favoriteTapped(_ sender: NSButton) {
        guard let urlString = sender.identifier?.rawValue else { return }
        
        // Update address bar
        addressBar.stringValue = urlString
        
        // Navigate to URL
        navigateToURL(urlString)
    }
    
    @objc func addressBarAction(_ sender: NSTextField) {
        let urlString = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        navigateToURL(urlString)
    }
    
    func navigateToURL(_ urlString: String) {
        var finalURL = urlString
        
        // Check if this looks like a URL or a search query
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's a search query (contains spaces, no dots, or doesn't look like a domain)
        let isSearchQuery = trimmed.contains(" ") || 
                           (!trimmed.contains(".") && !trimmed.hasPrefix("http")) ||
                           (trimmed.components(separatedBy: " ").count > 1)
        
        if isSearchQuery {
            // Create Google search URL
            let encodedQuery = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            finalURL = "https://www.google.com/search?q=\(encodedQuery)"
        } else {
            // Add https:// if no protocol is specified for URLs
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                finalURL = "https://" + urlString
            }
        }
        
        if let url = URL(string: finalURL) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func updateAddressBar(with url: String) {
        DispatchQueue.main.async {
            self.addressBar.stringValue = url
        }
    }
    
    func updateTitle(with title: String) {
        DispatchQueue.main.async {
            let displayTitle = title.isEmpty ? "WebMan - Native WebAuthn Browser" : title
            self.titleLabel.stringValue = displayTitle
            self.window.title = displayTitle
        }
    }
    
    func createMenuBar() {
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
        credentialsMenuItem.submenu = credentialsMenu
        mainMenu.addItem(credentialsMenuItem)
        
        // Debug Menu
        let debugMenuItem = NSMenuItem()
        let debugMenu = NSMenu(title: "Debug")
        
        debugMenu.addItem(NSMenuItem(title: "Test Database Functionality", action: #selector(testDatabase), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Clean Database Files", action: #selector(cleanDatabase), keyEquivalent: ""))
        
        debugMenuItem.submenu = debugMenu
        mainMenu.addItem(debugMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Menu Actions
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WebMan"
        alert.informativeText = """
            WebAuthn Client Application
            Version 1.0
            Core Features
            
            🔐 FIDO2/WebAuthn Compliant Passkeys
            Full standards compliance for secure authentication
            
            🔑 Custom Passkeys
            Personalized authentication experience with custom passkey implementation
            
            🔮 Future Plans
            This implementation will be adapted for cloud use and can turn any USB thumb drive into a PassKey Vault
            
            🕷️ WebKit-Powered Browser Application
            Built on WebAuthnWebView: WKWebView for seamless web integration
            
            🤖 100% AI-Generated Codebase
            Complete application stack including all frameworks developed by advanced AI
            
            ⚡ Innovative Development Process
            Powered by creative prompt engineering techniques from FIDO3
            
            🐶🪪 DogTag FIDO2/WebAuthn Frameworks by AI
            Created via the same prompt engineering process also from FIDO3

            Copyright 2025 FIDO3.ai & WebAuthn.ai
            """
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @objc func reloadWebView() {
        webView?.reload()
    }
    
    @objc func goBack() {
        webView?.goBack()
    }
    
    @objc func goForward() {
        webView?.goForward()
    }
    
    @objc func openDeveloperTools() {
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
    
    @objc func diagnoseCredentials() {
        print("🔍 Manual credential diagnostic triggered")
        LocalAuthService.shared.diagnoseCredentialAvailability(for: "chat.xcf.ai")
    }
    
    @objc func testDatabase() {
        print("🧪 Manual database test triggered")
        let success = LocalAuthService.shared.testDatabaseFunctionality()
        
        let alert = NSAlert()
        alert.messageText = "Database Test"
        alert.informativeText = success ? "Database test passed successfully!" : "Database test failed. Check the console for details."
        alert.alertStyle = success ? .informational : .warning
        alert.runModal()
    }
    
    @objc func cleanDatabase() {
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
    
    @objc func testSaveFavorites() {
        print("🧪 Testing favorites save...")
        saveFavoritesToUserDefaults()
        
        // Test loading too
        print("🧪 Testing favorites load...")
        let loaded = loadFavoritesFromUserDefaults()
        print("🧪 Loaded \(loaded.count) favorites: \(loaded)")
    }
    
    @objc func clearSavedFavorites() {
        print("🗑️ Clearing saved favorites...")
        UserDefaults.standard.removeObject(forKey: "WebManFavorites")
        UserDefaults.standard.synchronize()
        print("🗑️ Cleared! Restart app to see defaults.")
    }

    
    @objc func testTouchIDAuthentication() {
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
    
    @objc func checkBiometricAvailability() {
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

    @objc func testTouchIDSheet() {
        print("🔐 Testing Touch ID Sheet")
        
        // Show the Touch ID sheet directly without extra background window
        if let mainWindow = NSApp.mainWindow, let contentView = mainWindow.contentView {
            var hostingView: NSHostingView<TouchIDSignInSheet>?
            
            let touchIDSheet = TouchIDSignInSheet(
                siteName: "chat.xcf.ai",
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
    
    @objc func showWebInspector() {
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
    
    @objc func reloadPage() {
        webView?.reload()
    }
    
    @objc func showDogTagManager() {
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
        print("🐶🪪 DogTag Manager window closed")
        }
        
        self.dogTagWindow = window
        window.makeKeyAndOrderFront(nil)
        
        print("🐶🪪 DogTag Manager window opened")
    }
}
