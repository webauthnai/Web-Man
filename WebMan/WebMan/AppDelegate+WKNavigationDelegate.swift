//
//  AppDelegate+WKNavigationDelegate.swift
//  WebMan
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Foundation
import Cocoa
import WebKit

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
    
    public func handleDownload(from url: URL) {
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
    
    public func downloadFile(from sourceURL: URL, to destinationURL: URL) {
        isDownloading = true
        showDownloadProgress()
        
        // Create download task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: sourceURL)
        downloadTask?.resume()
        
        // Store destination URL for later use
        UserDefaults.standard.set(destinationURL.path, forKey: "downloadDestination")
    }
    
    public func showDownloadProgress() {
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
    
    public func hideDownloadProgress() {
        downloadProgressIndicator?.stopAnimation(nil)
        downloadProgressIndicator?.doubleValue = 0.0
        downloadStatusLabel?.stringValue = ""
        window?.title = "WebMan Browser2"
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        hideDownloadProgress()
    }
    
    public func navigationTypeName(_ type: WKNavigationType) -> String {
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
