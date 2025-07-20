//
//  AppDelegate+WKWebView.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa
import WebKit

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
