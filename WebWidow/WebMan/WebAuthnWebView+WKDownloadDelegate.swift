import Foundation
import WebKit

// MARK: - WKDownloadDelegate for proper download handling
extension WebAuthnWebView: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        print("💾 Download requested: \(suggestedFilename)")
        
        // Only allow actual downloads (not images/media that should be inline)
        let filename = suggestedFilename.lowercased()
        let inlineExtensions = ["svg", "png", "jpg", "jpeg", "gif", "webp", "ico", "bmp", "css", "js", "html", "htm"]
        
        let shouldPreventDownload = inlineExtensions.contains { filename.hasSuffix(".\($0)") }
        
        if shouldPreventDownload {
            print("🚫 Preventing download of inline content: \(suggestedFilename)")
            completionHandler(nil) // Cancel the download
            return
        }
        
        // Allow legitimate downloads to Downloads folder
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsPath.appendingPathComponent(suggestedFilename)
        print("✅ Allowing download to: \(destinationURL.path)")
        completionHandler(destinationURL)
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        print("✅ Download completed successfully")
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("❌ Download failed: \(error.localizedDescription)")
    }
} 