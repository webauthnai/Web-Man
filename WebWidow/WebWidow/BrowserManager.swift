//
//  BrowserManager.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Foundation
import WebKit
import SwiftUI

class BrowserManager: NSObject, ObservableObject {
    @Published var currentURL: String = ""
    @Published var addressBarText: String = ""
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var pageTitle: String = ""
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    @Published var downloadStatus: String = ""
    
    weak var webView: WKWebView?
    private var downloadTask: URLSessionDownloadTask?
    
    override init() {
        super.init()
    }
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        setupWebView()
    }
    
    private func setupWebView() {
        guard let webView = webView else { return }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Add observers for navigation properties
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    }
    
    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
    }
    
    func navigate(to urlString: String) {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add protocol if missing
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        guard let url = URL(string: urlToLoad) else { return }
        
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func reload() {
        if isLoading {
            webView?.stopLoading()
        } else {
            webView?.reload()
        }
    }
    
    func showDevTools() {
        #if DEBUG
        if let webView = webView {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        #endif
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
        downloadStatus = ""
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = webView else { return }
        
        DispatchQueue.main.async {
            switch keyPath {
            case #keyPath(WKWebView.canGoBack):
                self.canGoBack = webView.canGoBack
            case #keyPath(WKWebView.canGoForward):
                self.canGoForward = webView.canGoForward
            case #keyPath(WKWebView.isLoading):
                self.isLoading = webView.isLoading
            case #keyPath(WKWebView.title):
                self.pageTitle = webView.title ?? ""
            case #keyPath(WKWebView.url):
                self.currentURL = webView.url?.absoluteString ?? ""
                self.addressBarText = self.currentURL
            default:
                break
            }
        }
    }
}

extension BrowserManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }
    
    // CRITICAL: Allow navigation actions (link clicks)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("🔗 Navigation action requested:")
        print("   - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("   - Navigation type: \(navigationAction.navigationType.rawValue)")
        print("   - Target frame: \(navigationAction.targetFrame?.isMainFrame ?? false)")
        
        // Allow all navigation actions (including link clicks)
        decisionHandler(.allow)
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
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.downloadStatus = "Starting download..."
        }
        
        // Create download task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: sourceURL)
        downloadTask?.resume()
        
        // Store destination URL for later use
        UserDefaults.standard.set(destinationURL.path, forKey: "downloadDestination")
    }
}

extension BrowserManager: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle popup windows
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
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
    
    // Handle JavaScript alerts, confirms, and prompts
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Alert"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirm"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
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
}

