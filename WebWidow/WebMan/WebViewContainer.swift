import Foundation
import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    @EnvironmentObject var browserManager: BrowserManager
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WebAuthnWebView()
        
        print("🔧 Created WebAuthnWebView, setting up browserManager...")
        browserManager.setWebView(webView)
        
        print("🔧 Navigation delegate set to: \(String(describing: webView.navigationDelegate))")
        print("🔧 UI delegate set to: \(String(describing: webView.uiDelegate))")
        
        // Load initial URL
        if let url = URL(string: browserManager.currentURL) {
            print("🔧 Loading initial URL: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Handle updates if needed
    }
}
