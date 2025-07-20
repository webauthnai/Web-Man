import Foundation
import WebKit

// MARK: - WKNavigationDelegate for WebAuthnWebView
extension WebAuthnWebView {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("🔗 WebAuthnWebView navigation action:")
        print("   - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("   - Navigation type: \(navigationAction.navigationType.rawValue)")
        print("   - Target frame: \(String(describing: navigationAction.targetFrame?.isMainFrame))")
        
        // Allow all navigation actions (including link clicks)
        decisionHandler(.allow)
    }
    
    // CRITICAL: Enable JavaScript per-navigation (modern API)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        print("🔗 WebAuthnWebView navigation action (with preferences):")
        print("   - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("   - Enabling JavaScript for this navigation")
        
        // Enable JavaScript for this navigation
        preferences.allowsContentJavaScript = true
        decisionHandler(.allow, preferences)
    }
    
    // CRITICAL: Handle response policy to prevent unwanted downloads
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }
        
        let urlString = url.absoluteString.lowercased()
        let pathExtension = url.pathExtension.lowercased()
        
        // Debug: Log all response details for images
        if urlString.contains(".svg") || urlString.contains("img/") || urlString.contains("logo") {
            print("🖼️ IMAGE RESPONSE DEBUG:")
            print("   - URL: \(url.absoluteString)")
            print("   - Extension: .\(pathExtension)")
            print("   - MIME Type: \(navigationResponse.response.mimeType ?? "unknown")")
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
                print("   - Content-Disposition: \(httpResponse.allHeaderFields["Content-Disposition"] ?? "none")")
            }
        }
        
        // Define file types that should be displayed inline (not downloaded)
        let inlineImageTypes = ["svg", "png", "jpg", "jpeg", "gif", "webp", "ico", "bmp"]
        let inlineDocumentTypes = ["html", "htm", "css", "js", "json", "xml", "txt"]
        let inlineMediaTypes = ["mp4", "webm", "ogg", "mp3", "wav", "m4a"]
        
        let allInlineTypes = inlineImageTypes + inlineDocumentTypes + inlineMediaTypes
        
        // Check if this is a file type that should be displayed inline
        if allInlineTypes.contains(pathExtension) {
            print("🖼️ ✅ FORCING INLINE: \(url.lastPathComponent) (.\(pathExtension))")
            decisionHandler(.allow)
            return
        }
        
        // Check for image MIME types (in case extension is missing)
        if let mimeType = navigationResponse.response.mimeType?.lowercased() {
            let inlineMimeTypes = [
                "image/", "text/", "application/javascript", "application/json",
                "application/xml", "video/", "audio/", "application/pdf"
            ]
            
            for inlineType in inlineMimeTypes {
                if mimeType.hasPrefix(inlineType) {
                    print("🖼️ Displaying inline content by MIME type: \(mimeType)")
                    decisionHandler(.allow)
                    return
                }
            }
        }
        
        // Check if this might be a download based on Content-Disposition header
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                if contentDisposition.lowercased().contains("attachment") {
                    print("💾 Content-Disposition indicates download: \(contentDisposition)")
                    // This is intentionally marked as a download, allow it
                    decisionHandler(.allow)
                    return
                }
            }
        }
        
        // For everything else, allow it (default behavior)
        print("✅ Allowing navigation response: \(url.lastPathComponent)")
        decisionHandler(.allow)
    }
} 