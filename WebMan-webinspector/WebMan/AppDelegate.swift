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
    var titleLabel: DraggableTitleLabel!
    
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
    
    private func setupUnifiedToolbar() {
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
        (titleLabel as! DraggableTitleLabel).addressBar = addressBar
        
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
    
    private func setupFavoritesAccessory() {
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
    
    private func setupMainContentWithFavorites() {
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
    
    private func createFavoritesToolbar() -> NSView {
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
   
    @objc private func addCurrentPageToFavorites(_ sender: NSButton) {
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
    
    @objc private func dragButtonClicked(_ sender: NSButton) {
        // Provide feedback that this button is for dragging
        print("🔗 Drag the link icon to add current URL as bookmark")
    }
    
    // MARK: - UserDefaults for Favorites
    
    public func saveFavoritesToUserDefaults() {
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
    
    private func loadFavoritesFromUserDefaults() -> [(name: String, url: String)] {
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
    
    private func getDefaultFavorites() -> [(name: String, url: String)] {
        return [
            ("💬 chat.xcf.ai", "https://chat.xcf.ai"),
            ("🐙 github/webauthnai", "https://github.com/webauthnai"),
            ("🤖 xcf.ai", "https://xcf.ai"),
            ("🧠 d1f.ai", "https://d1f.ai"),
            ("❄️ codefreeze.ai", "https://codefreeze.ai"),
            ("🚀 superbox64.com", "https://superbox64.com"),
            ("📱 apps.apple.com", "https://apps.apple.com/ba/developer/todd-bruss/id1239131660"),
            ("🎮 github/SuperBox64", "https://github.com/SuperBox64?tab=repositories"),
            ("❄️ github/CodeFreezeAI", "https://github.com/orgs/CodeFreezeAI/repositories"),
            ("⭐️ WebAuthn.me", "https://webauthn.me"),
            ("🔐 WebAuthn.io", "https://webauthn.io")
        ]
    }
    
    private func findFavoritesToolbar() -> FavoritesToolbar? {
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
    
    private func createFavoriteButton(name: String, url: String) -> DraggableFavoriteButton {
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
    
    private func createTrashCan() -> TrashCanView {
        let trashCan = TrashCanView()
        trashCan.wantsLayer = true
        trashCan.layer?.backgroundColor = NSColor.clear.cgColor
        
        return trashCan
    }
    
    @objc private func favoriteTapped(_ sender: NSButton) {
        guard let urlString = sender.identifier?.rawValue else { return }
        
        // Update address bar
        addressBar.stringValue = urlString
        
        // Navigate to URL
        navigateToURL(urlString)
    }
    
    @objc private func addressBarAction(_ sender: NSTextField) {
        let urlString = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        navigateToURL(urlString)
    }
    
    private func navigateToURL(_ urlString: String) {
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
        
        debugMenu.addItem(NSMenuItem(title: "Test Database Functionality", action: #selector(testDatabase), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Clean Database Files", action: #selector(cleanDatabase), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem.separator())
        debugMenu.addItem(NSMenuItem(title: "Test Save Favorites", action: #selector(testSaveFavorites), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Clear Saved Favorites", action: #selector(clearSavedFavorites), keyEquivalent: ""))

        
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
        LocalAuthService.shared.diagnoseCredentialAvailability(for: "chat.xcf.ai")
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
    
    @objc private func testSaveFavorites() {
        print("🧪 Testing favorites save...")
        saveFavoritesToUserDefaults()
        
        // Test loading too
        print("🧪 Testing favorites load...")
        let loaded = loadFavoritesFromUserDefaults()
        print("🧪 Loaded \(loaded.count) favorites: \(loaded)")
    }
    
    @objc private func clearSavedFavorites() {
        print("🗑️ Clearing saved favorites...")
        UserDefaults.standard.removeObject(forKey: "WebManFavorites")
        UserDefaults.standard.synchronize()
        print("🗑️ Cleared! Restart app to see defaults.")
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
        print("🐶🪪 DogTag Manager window closed")
        }
        
        self.dogTagWindow = window
        window.makeKeyAndOrderFront(nil)
        
        print("🐶🪪 DogTag Manager window opened")
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
        print("🐶🪪 DogTagWindow deallocated")
        cleanupSwiftUIContent()
    }
}

extension DogTagWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("🐶🪪 DogTag Manager window should close")
        // Clean up SwiftUI content before closing
        cleanupSwiftUIContent()
        appDelegate?.dogTagWindow = nil
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        print("🐶🪪 DogTag Manager window will close")
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
        
        // Always try to update title, even if empty initially
        let currentTitle = webView.title ?? ""
        updateTitle(with: currentTitle)
        
        // Also check for title after a brief delay for dynamic updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let delayedTitle = webView.title, !delayedTitle.isEmpty {
                self.updateTitle(with: delayedTitle)
            }
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
    
    // Handle navigation failures - redirect to Google
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("🚨 Navigation failed: \(error.localizedDescription)")
        
        // Don't redirect if user is already on Google or if this was a Google redirect
        guard let currentURL = webView.url?.absoluteString,
              !currentURL.contains("google.com") else {
            return
        }
        
        // Redirect to Google as fallback
        print("↪️ Redirecting to Google due to navigation failure")
        if let googleURL = URL(string: "https://google.com") {
            webView.load(URLRequest(url: googleURL))
            updateAddressBar(with: "https://google.com")
        }
    }
    
    // Handle navigation errors after loading starts
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("🚨 Navigation error: \(error.localizedDescription)")
        
        // Don't redirect if user is already on Google
        guard let currentURL = webView.url?.absoluteString,
              !currentURL.contains("google.com") else {
            return
        }
        
        // Redirect to Google as fallback
        print("↪️ Redirecting to Google due to navigation error")
        if let googleURL = URL(string: "https://google.com") {
            webView.load(URLRequest(url: googleURL))
            updateAddressBar(with: "https://google.com")
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

// MARK: - FavoritesToolbar with Drag and Drop
protocol FavoritesToolbarDelegate: AnyObject {
    func addFavorite(name: String, url: String)
    func addFavoriteAtIndex(name: String, url: String, index: Int)
    func reorderFavorite(from sourceIndex: Int, to destinationIndex: Int)
    func deleteFavorite(at index: Int)
}

protocol DraggableFavoriteDelegate: AnyObject {
    func favoriteWantsToMove(_ button: DraggableFavoriteButton, to location: NSPoint)
}

protocol TrashCanDelegate: AnyObject {
    func deleteFavorite(at index: Int)
}

// MARK: - TrashCanView for Bookmark Deletion
class TrashCanView: NSView {
    weak var delegate: TrashCanDelegate?
    private var isHighlighted = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTrashCan()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrashCan()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrashCan()
    }
    
    private func setupTrashCan() {
        registerForDraggedTypes([.string])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw trash can icon
        let iconSize: CGFloat = 16
        let iconRect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        let color = isHighlighted ? NSColor.systemRed : NSColor.tertiaryLabelColor
        
        // Simple trash can drawing
        color.setStroke()
        color.setFill()
        
        let path = NSBezierPath()
        // Trash can body
        path.move(to: NSPoint(x: iconRect.minX + 3, y: iconRect.minY + 2))
        path.line(to: NSPoint(x: iconRect.maxX - 3, y: iconRect.minY + 2))
        path.line(to: NSPoint(x: iconRect.maxX - 4, y: iconRect.maxY - 4))
        path.line(to: NSPoint(x: iconRect.minX + 4, y: iconRect.maxY - 4))
        path.close()
        
        // Trash can lid
        let lidPath = NSBezierPath()
        lidPath.move(to: NSPoint(x: iconRect.minX + 2, y: iconRect.maxY - 3))
        lidPath.line(to: NSPoint(x: iconRect.maxX - 2, y: iconRect.maxY - 3))
        
        path.lineWidth = 1.5
        lidPath.lineWidth = 1.5
        
        path.stroke()
        lidPath.stroke()
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let stringValue = sender.draggingPasteboard.string(forType: .string),
              stringValue == "favorite_reorder" else {
            return []
        }
        
        isHighlighted = true
        needsDisplay = true
        return .delete
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        needsDisplay = true
        
        guard let stringValue = sender.draggingPasteboard.string(forType: .string),
              stringValue == "favorite_reorder" else {
            return false
        }
        
        // Find the dragged button and its index
        if let toolbar = superview?.superview as? FavoritesToolbar,
           let stackView = toolbar.stackView {
            
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                if let button = view as? DraggableFavoriteButton, button.alphaValue < 1.0 {
                    delegate?.deleteFavorite(at: index)
                    return true
                }
            }
        }
        
        return false
    }
}

class FavoritesToolbar: NSView {
    weak var delegate: FavoritesToolbarDelegate?
    var stackView: NSStackView?
    var scrollView: NSScrollView?
    var trashCan: TrashCanView?
    private var insertionIndex: Int = -1
    private var originalSpacing: CGFloat = 8
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupDragAndDrop()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        // Register for URL drops and favorite reordering
        registerForDraggedTypes([.URL, .string])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.URL.rawValue, NSPasteboard.PasteboardType.string.rawValue]) else {
            return []
        }
        
        let pasteboard = sender.draggingPasteboard
        
        // Check if this is a reorder operation
        if let stringValue = pasteboard.string(forType: .string), stringValue == "favorite_reorder" {
            return .move
        } else if let stringValue = pasteboard.string(forType: .string), 
                  stringValue.hasPrefix("emoji_bookmark_add:") {
            return .copy
        } else {
            return []
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let stringValue = sender.draggingPasteboard.string(forType: .string),
              let stackView = stackView else {
            return draggingEntered(sender)
        }
        
        if stringValue == "favorite_reorder" {
            let dropLocation = convert(sender.draggingLocation, from: nil)
            let newInsertionIndex = calculateInsertionIndex(at: dropLocation)
            
            if newInsertionIndex != insertionIndex {
                updateInsertionPoint(to: newInsertionIndex)
            }
            
            return .move
        } else if stringValue.hasPrefix("emoji_bookmark_add:") {
            let dropLocation = convert(sender.draggingLocation, from: nil)
            let newInsertionIndex = calculateInsertionIndex(at: dropLocation)
            
            if newInsertionIndex != insertionIndex {
                updateInsertionPoint(to: newInsertionIndex)
            }
            
            return .copy
        }
        
        return draggingEntered(sender)
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearInsertionPoint()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        clearInsertionPoint()
        
        let pasteboard = sender.draggingPasteboard
        
        if let stringValue = pasteboard.string(forType: .string), stringValue == "favorite_reorder" {
            return handleFavoriteReorder(sender)
        } else if let dragString = pasteboard.string(forType: .string),
                  dragString.hasPrefix("emoji_bookmark_add:") {
            let urlString = String(dragString.dropFirst("emoji_bookmark_add:".count))
            if let url = URL(string: urlString) {
                let siteName = url.host?.replacingOccurrences(of: "www.", with: "") ?? "New Site"
                let displayName = "🌐 \(siteName.capitalized)"
                
                // Calculate insertion index fresh from current drop location
                let dropLocation = convert(sender.draggingLocation, from: nil)
                let targetIndex = calculateInsertionIndex(at: dropLocation)
                
                print("🎯 EMOJI DROP: Calculated insertion index: \(targetIndex)")
                delegate?.addFavoriteAtIndex(name: displayName, url: urlString, index: targetIndex)
                
                // Extra save to ensure persistence after drag
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let appDelegate = self.delegate as? AppDelegate {
                        appDelegate.saveFavoritesToUserDefaults()
                    }
                }
                return true
            }
        }
        
        return false
    }
    
    private func handleFavoriteReorder(_ sender: NSDraggingInfo) -> Bool {
        guard let stackView = stackView else { return false }
        
        let dropLocation = convert(sender.draggingLocation, from: nil)
        var targetIndex = 0
        
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            if view is DraggableFavoriteButton {
                let buttonFrame = view.frame
                if dropLocation.x < buttonFrame.midX {
                    targetIndex = index
                    break
                }
                targetIndex = index + 1
            }
        }
        
        var sourceIndex = -1
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            if let button = view as? DraggableFavoriteButton, button.alphaValue < 1.0 {
                sourceIndex = index
                break
            }
        }
        
        if sourceIndex >= 0 && sourceIndex != targetIndex {
            delegate?.reorderFavorite(from: sourceIndex, to: targetIndex)
            
            // Extra save to ensure persistence after drag reorder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let appDelegate = self.delegate as? AppDelegate {
                    appDelegate.saveFavoritesToUserDefaults()
                }
            }
            return true
        }
        
        return false
    }
    
    private func calculateInsertionIndex(at location: NSPoint) -> Int {
        guard let stackView = stackView else { 
            print("🎯 No stackView found")
            return 0 
        }
        
        var insertionIndex = 0
        
        // Convert location directly to stackView's coordinate system
        let localLocation = stackView.convert(location, from: self)
        print("🎯 Drop location: \(location) -> Local: \(localLocation)")
        print("🎯 StackView frame: \(stackView.frame)")
        print("🎯 StackView bounds: \(stackView.bounds)")
        
        let favoriteButtons = stackView.arrangedSubviews.compactMap { $0 as? DraggableFavoriteButton }
        print("🎯 Found \(favoriteButtons.count) favorite buttons")
        
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            guard view is DraggableFavoriteButton else { continue }
            
            let buttonFrame = view.frame
            let buttonCenter = buttonFrame.midX
            
            print("🎯 Button \(index): frame=\(buttonFrame), center=\(buttonCenter), dropX=\(localLocation.x)")
            
            if localLocation.x < buttonCenter {
                insertionIndex = index
                print("🎯 Inserting at index \(index) (before button)")
                break
            }
            insertionIndex = index + 1
            print("🎯 Continuing... insertionIndex now \(insertionIndex)")
        }
        
        print("🎯 Final insertion index: \(insertionIndex)")
        return insertionIndex
    }
    
    private func updateInsertionPoint(to newIndex: Int) {
        guard let stackView = stackView else { return }
        guard newIndex != insertionIndex else { return }
        
        print("🎯 Updating insertion point to index: \(newIndex)")
        
        // Clear previous insertion point
        clearInsertionPoint()
        
        // Set new insertion index
        insertionIndex = newIndex
        
        // Create visual gap with SMOOTH animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                guard view is DraggableFavoriteButton else { continue }
                
                // Special handling for different insertion positions
                if insertionIndex == 0 && index == 0 {
                    // Inserting at the very beginning - add spacing before first item
                    continue
                } else if index == insertionIndex - 1 {
                    // Add extra spacing after the view that comes before insertion point
                    stackView.setCustomSpacing(originalSpacing + 20, after: view)
                    print("🎯 Added gap after button at index \(index)")
                } else {
                    // Normal spacing
                    stackView.setCustomSpacing(originalSpacing, after: view)
                }
            }
            
            // For insertion at beginning, adjust scroll view content insets
            if insertionIndex == 0, let scrollView = scrollView {
                scrollView.contentInsets.left = 20
                print("🎯 Added gap at beginning")
            }
        }
    }
    
    private func clearInsertionPoint() {
        guard let stackView = stackView else { return }
        guard insertionIndex != -1 else { return }
        
        let wasInsertingAtStart = (insertionIndex == 0)
        insertionIndex = -1
        
        // Restore original spacing with SMOOTH animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            for view in stackView.arrangedSubviews {
                guard view is DraggableFavoriteButton else { continue }
                stackView.setCustomSpacing(originalSpacing, after: view)
            }
            
            // Reset scroll view content insets if we were inserting at start
            if wasInsertingAtStart, let scrollView = scrollView {
                scrollView.contentInsets.left = 0
            }
        }
    }
}

// MARK: - DraggableFavoriteButton for Reordering
class DraggableFavoriteButton: NSButton {
    weak var delegate: DraggableFavoriteDelegate?
    var favoriteURL: String = ""
    private var originalSuperview: NSView?
    private var trackingArea: NSTrackingArea?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTrackingArea()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // No hover effects - completely flat buttons
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // No hover effects - completely flat buttons
    }
    
    override func mouseDown(with event: NSEvent) {
        let startPoint = event.locationInWindow
        var dragStarted = false
        
        window?.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: .eventTracking) { dragEvent, stop in
            guard let dragEvent = dragEvent else { return }
            
            let currentPoint = dragEvent.locationInWindow
            let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
            
            if dragEvent.type == .leftMouseDragged && distance > 5 && !dragStarted {
                dragStarted = true
                self.startReorderDrag(with: dragEvent)
                stop.pointee = true
            } else if dragEvent.type == .leftMouseUp {
                stop.pointee = true
                if !dragStarted {
                    self.performClick(nil)
                }
            }
        }
    }
    
    private func startReorderDrag(with event: NSEvent) {
        guard let stackView = superview as? NSStackView else { return }
        
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.setString("favorite_reorder", forType: .string)
        
        let titleText = title
        let textSize = titleText.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ])
        
        let dragSize = NSSize(
            width: max(textSize.width + 12, 80), 
            height: max(textSize.height + 8, 24)
        )
        
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: dragSize), xRadius: 6, yRadius: 6).fill()
        
        let textRect = NSRect(
            x: 6,
            y: (dragSize.height - textSize.height) / 2,
            width: dragSize.width - 12,
            height: textSize.height
        )
        
        titleText.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor
        ])
        
        dragImage.unlockFocus()
        
        let dragItem = NSDraggingItem(pasteboardWriter: "favorite_reorder" as NSString)
        dragItem.setDraggingFrame(NSRect(origin: .zero, size: dragSize), contents: dragImage)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}

extension DraggableFavoriteButton: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        alphaValue = 0.5
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        alphaValue = 1.0
    }
}

// MARK: - FavoritesToolbarDelegate
extension AppDelegate: FavoritesToolbarDelegate, DraggableFavoriteDelegate, TrashCanDelegate {
    func favoriteWantsToMove(_ button: DraggableFavoriteButton, to location: NSPoint) {
        // This could be used for more advanced reordering feedback if needed
    }
    
    func addFavorite(name: String, url: String) {
        print("🌟 Adding new favorite: \(name) -> \(url)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar")
            return
        }
        
        let newButton = createFavoriteButton(name: name, url: url)
        stackView.addArrangedSubview(newButton)
        
        newButton.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            newButton.alphaValue = 1
        }
        
        showTemporaryMessage("⭐️ Added to favorites!")
    }
    
    func addFavoriteAtIndex(name: String, url: String, index: Int) {
        print("🌟 Adding new favorite at index \(index): \(name) -> \(url)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar")
            return
        }
        
        print("🌟 StackView has \(stackView.arrangedSubviews.count) subviews before insertion")
        
        let newButton = createFavoriteButton(name: name, url: url)
        
        if index >= 0 && index < stackView.arrangedSubviews.count {
            print("🌟 Inserting at specific index \(index)")
            stackView.insertArrangedSubview(newButton, at: index)
        } else {
            print("🌟 Adding to end (index \(index) out of range)")
            stackView.addArrangedSubview(newButton)
        }
        
        print("🌟 StackView has \(stackView.arrangedSubviews.count) subviews after insertion")
        
        newButton.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            newButton.alphaValue = 1
        }
        
        // Save favorites to UserDefaults
        print("🌟 About to save favorites after adding new one...")
        saveFavoritesToUserDefaults()
        
        showTemporaryMessage("⭐️ Added to favorites!")
    }
    
    func reorderFavorite(from sourceIndex: Int, to destinationIndex: Int) {
        print("🔄 Reordering favorite from \(sourceIndex) to \(destinationIndex)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar for reordering")
            return
        }
        
        let arrangedSubviews = stackView.arrangedSubviews
        guard sourceIndex < arrangedSubviews.count,
              destinationIndex <= arrangedSubviews.count,
              let sourceView = arrangedSubviews[sourceIndex] as? DraggableFavoriteButton else {
            print("❌ Invalid reorder indices")
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            stackView.removeArrangedSubview(sourceView)
            
            let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
            stackView.insertArrangedSubview(sourceView, at: adjustedDestination)
            
            sourceView.alphaValue = 1.0
        }
        
        // Save favorites to UserDefaults after reordering
        print("↔️ About to save favorites after reordering...")
        saveFavoritesToUserDefaults()
        
        showTemporaryMessage("↔️ Favorites reordered!")
    }
    
    func deleteFavorite(at index: Int) {
        print("🗑️ Deleting favorite at index \(index)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar for deletion")
            return
        }
        
        let arrangedSubviews = stackView.arrangedSubviews
        guard index < arrangedSubviews.count,
              let buttonToDelete = arrangedSubviews[index] as? DraggableFavoriteButton else {
            print("❌ Invalid deletion index or button not found")
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            buttonToDelete.alphaValue = 0
            buttonToDelete.layer?.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        } completionHandler: {
            stackView.removeArrangedSubview(buttonToDelete)
            buttonToDelete.removeFromSuperview()
            
            // Save favorites to UserDefaults after deletion
            print("🗑️ About to save favorites after deletion...")
            self.saveFavoritesToUserDefaults()
        }
        
        showTemporaryMessage("🗑️ Bookmark deleted!")
    }
    
    private func showTemporaryMessage(_ message: String) {
        let originalTitle = window.title
        window.title = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.window.title = originalTitle
        }
    }
}

// MARK: - DraggableEmojiButton for Address Bar
class DraggableEmojiButton: NSButton {
    weak var addressBar: NSTextField?
    
    override func mouseDown(with event: NSEvent) {
        guard let addressBar = addressBar,
              let urlString = addressBar.stringValue as String?,
              !urlString.isEmpty,
              (urlString.hasPrefix("http") || urlString.contains(".")) else {
            super.mouseDown(with: event)
            return
        }
        
        let startPoint = event.locationInWindow
        var dragStarted = false
        
        window?.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: .eventTracking) { dragEvent, stop in
            guard let dragEvent = dragEvent else { return }
            
            let currentPoint = dragEvent.locationInWindow
            let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
            
            if dragEvent.type == .leftMouseDragged && distance > 5 && !dragStarted {
                dragStarted = true
                self.startDragOperation(with: urlString, event: dragEvent)
                stop.pointee = true
            } else if dragEvent.type == .leftMouseUp {
                stop.pointee = true
                if !dragStarted {
                    // This was just a click, perform normal action
                    self.performClick(nil)
                }
            }
        }
    }
    
    private func startDragOperation(with urlString: String, event: NSEvent) {
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.setString("emoji_bookmark_add:\(urlString)", forType: .string)
        
        // Create PROPER drag image with SF Symbol and URL
        let truncatedURL = urlString.count > 18 ? String(urlString.prefix(18)) + "..." : urlString
        let textSize = truncatedURL.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ])
        
        let iconSize: CGFloat = 14
        let spacing: CGFloat = 6
        let padding: CGFloat = 8
        
        let dragSize = NSSize(
            width: max(iconSize + spacing + textSize.width + padding * 2, 100),
            height: max(iconSize + padding, 26)
        )
        
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        
        // Draw background only - no border
        NSColor.systemBlue.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: dragSize), xRadius: 6, yRadius: 6).fill()
        
        // Draw SF Symbol link icon
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        if let linkIcon = NSImage(systemSymbolName: "link", accessibilityDescription: "Link")?.withSymbolConfiguration(config) {
            linkIcon.isTemplate = true
            let iconRect = NSRect(
                x: padding,
                y: (dragSize.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            // Draw icon with blue tint
            NSColor.systemBlue.set()
            linkIcon.draw(in: iconRect)
        }
        
        // Draw URL text next to icon
        let textRect = NSRect(
            x: padding + iconSize + spacing,
            y: (dragSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        truncatedURL.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.systemBlue
        ])
        
        dragImage.unlockFocus()
        
        let dragItem = NSDraggingItem(pasteboardWriter: "emoji_bookmark_add:\(urlString)" as NSString)
        dragItem.setDraggingFrame(NSRect(origin: .zero, size: dragSize), contents: dragImage)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}

extension DraggableEmojiButton: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

// MARK: - DraggableTitleLabel for Website Title
class DraggableTitleLabel: NSTextField {
    weak var addressBar: NSTextField?
    
    override func mouseDown(with event: NSEvent) {
        guard let addressBar = addressBar,
              let urlString = addressBar.stringValue as String?,
              !urlString.isEmpty,
              (urlString.hasPrefix("http") || urlString.contains(".")) else {
            super.mouseDown(with: event)
            return
        }
        
        let startPoint = event.locationInWindow
        var dragStarted = false
        
        window?.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: .eventTracking) { dragEvent, stop in
            guard let dragEvent = dragEvent else { return }
            
            let currentPoint = dragEvent.locationInWindow
            let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
            
            if dragEvent.type == .leftMouseDragged && distance > 5 && !dragStarted {
                dragStarted = true
                self.startDragOperation(with: urlString, event: dragEvent)
                stop.pointee = true
            } else if dragEvent.type == .leftMouseUp {
                stop.pointee = true
                if !dragStarted {
                    // This was just a click, handle normally
                    super.mouseDown(with: event)
                }
            }
        }
    }
    
    private func startDragOperation(with urlString: String, event: NSEvent) {
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.setString("emoji_bookmark_add:\(urlString)", forType: .string)
        
        // Create drag image with page title and URL
        let pageTitle = self.stringValue.isEmpty ? "Webpage" : self.stringValue
        let truncatedTitle = pageTitle.count > 20 ? String(pageTitle.prefix(20)) + "..." : pageTitle
        let truncatedURL = urlString.count > 18 ? String(urlString.prefix(18)) + "..." : urlString
        
        let titleSize = truncatedTitle.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ])
        let urlSize = truncatedURL.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular)
        ])
        
        let padding: CGFloat = 8
        let lineSpacing: CGFloat = 2
        
        let dragSize = NSSize(
            width: max(titleSize.width, urlSize.width) + padding * 2,
            height: titleSize.height + urlSize.height + lineSpacing + padding * 2
        )
        
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        
        // Draw background
        NSColor.systemBlue.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: dragSize), xRadius: 6, yRadius: 6).fill()
        
        // Draw page title
        let titleRect = NSRect(
            x: padding,
            y: padding + urlSize.height + lineSpacing,
            width: titleSize.width,
            height: titleSize.height
        )
        
        truncatedTitle.draw(in: titleRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.systemBlue
        ])
        
        // Draw URL
        let urlRect = NSRect(
            x: padding,
            y: padding,
            width: urlSize.width,
            height: urlSize.height
        )
        
        truncatedURL.draw(in: urlRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.systemBlue.withAlphaComponent(0.7)
        ])
        
        dragImage.unlockFocus()
        
        let dragItem = NSDraggingItem(pasteboardWriter: "emoji_bookmark_add:\(urlString)" as NSString)
        dragItem.setDraggingFrame(NSRect(origin: .zero, size: dragSize), contents: dragImage)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}

extension DraggableTitleLabel: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

 
