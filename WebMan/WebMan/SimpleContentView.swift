import SwiftUI
import WebKit
import AuthenticationServices
import DogTagClient
import UniformTypeIdentifiers

struct SimpleWebView: NSViewRepresentable {
    @Binding var urlText: String
    @Binding var webView: WKWebView?
    @Binding var downloadProgress: Double
    @Binding var isDownloading: Bool
    @Binding var downloadStatus: String
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // CRITICAL: Enable JavaScript via modern API (set in navigation delegate)
        // Note: JavaScript is now enabled per-navigation using WKWebpagePreferences
        
        // Enable WebAuthn and modern web features
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Critical WebAuthn settings
        config.preferences.setValue(true, forKey: "webAuthenticationEnabled")
        config.preferences.setValue(true, forKey: "fraudulentWebsiteWarningEnabled")
        config.setValue(true, forKey: "allowsInlineMediaPlayback")
        
        // Enable secure context for WebAuthn
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let userScript = WKUserScript(source: webAuthnScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Add native WebAuthn message handler AFTER webView is created
        let webAuthnHandler = WebAuthnNativeHandler(webView: webView)
        webView.configuration.userContentController.add(webAuthnHandler, name: "webAuthnNative")
        
        // Load initial URL
        if let url = URL(string: urlText) {
            webView.load(URLRequest(url: url))
        }
        
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Updates handled in coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: SimpleWebView
        private var downloadTask: URLSessionDownloadTask?
        
        init(_ parent: SimpleWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                DispatchQueue.main.async {
                    self.parent.urlText = url.absoluteString
                }
            }
        }
        
        // Handle navigation failures - redirect to Google
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("🚨 SimpleWebView navigation failed: \(error.localizedDescription)")
            
            // Don't redirect if user is already on Google
            guard let currentURL = webView.url?.absoluteString,
                  !currentURL.contains("google.com") else {
                return
            }
            
            // Redirect to Google as fallback
            print("↪️ SimpleWebView redirecting to Google due to navigation failure")
            if let googleURL = URL(string: "https://google.com") {
                webView.load(URLRequest(url: googleURL))
                DispatchQueue.main.async {
                    self.parent.urlText = "https://google.com"
                }
            }
        }
        
        // Handle navigation errors after loading starts
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("🚨 SimpleWebView navigation error: \(error.localizedDescription)")
            
            // Don't redirect if user is already on Google
            guard let currentURL = webView.url?.absoluteString,
                  !currentURL.contains("google.com") else {
                return
            }
            
            // Redirect to Google as fallback
            print("↪️ SimpleWebView redirecting to Google due to navigation error")
            if let googleURL = URL(string: "https://google.com") {
                webView.load(URLRequest(url: googleURL))
                DispatchQueue.main.async {
                    self.parent.urlText = "https://google.com"
                }
            }
        }
        
        // CRITICAL: Allow navigation actions (link clicks)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation actions (including link clicks)
            decisionHandler(.allow)
        }
        
        // CRITICAL: Enable JavaScript per-navigation (modern API)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // Enable JavaScript for this navigation
            preferences.allowsContentJavaScript = true
            decisionHandler(.allow, preferences)
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
            DispatchQueue.main.async {
                self.parent.isDownloading = true
                self.parent.downloadProgress = 0.0
                self.parent.downloadStatus = "Starting download..."
            }
            
            // Create download task
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            downloadTask = session.downloadTask(with: sourceURL)
            downloadTask?.resume()
            
            // Store destination URL for later use
            UserDefaults.standard.set(destinationURL.path, forKey: "downloadDestination")
        }
        
        // CRITICAL: Handle WebAuthn authorization
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("🔐 WebAuthn authorization request: \(message)")
            completionHandler(true)
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("🔐 WebAuthn alert: \(message)")
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
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
        
        // Handle popup windows
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension SimpleWebView.Coordinator: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.parent.downloadProgress = progress
            self.parent.downloadStatus = "Downloading... \(Int(progress * 100))%"
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
                self.parent.isDownloading = false
                self.parent.downloadProgress = 1.0
                self.parent.downloadStatus = "Download completed successfully!"
                
                // Clear status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.parent.downloadStatus = ""
                    self.parent.downloadProgress = 0.0
                }
            }
            
            print("✅ Download completed: \(destinationURL.path)")
        } catch {
            DispatchQueue.main.async {
                self.parent.isDownloading = false
                self.parent.downloadStatus = "Download failed: \(error.localizedDescription)"
                
                // Clear status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.parent.downloadStatus = ""
                    self.parent.downloadProgress = 0.0
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
                self.parent.isDownloading = false
                self.parent.downloadStatus = "Download failed: \(error.localizedDescription)"
                
                // Clear status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.parent.downloadStatus = ""
                    self.parent.downloadProgress = 0.0
                }
            }
            print("❌ Download task failed: \(error)")
        }
    }
}

