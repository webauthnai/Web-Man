//
//  AppDelegate+URLSessionDownloadDelegate.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Foundation
import Cocoa

// MARK: - URLSessionDownloadDelegate
extension AppDelegate: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgressIndicator?.doubleValue = progress
            let percentage = Int(progress * 100)
            self.window?.title = "WebWidow Browser - Downloading... \(percentage)%"
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
                self.window?.title = "WebWidow Browser - Download Complete!"
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
                    self.window?.title = "WebWidow Browser"
                }
            }
            
            print("✅ Download completed: \(destinationURL.path)")
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.window?.title = "WebWidow Browser - Download Failed"
                self.hideDownloadProgress()
                
                let alert = NSAlert()
                alert.messageText = "Download Failed"
                alert.informativeText = "Error: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
                
                // Reset title after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.window?.title = "WebWidow Browser"
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
                self.window?.title = "WebWidow Browser - Download Failed"
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
                    self.window?.title = "WebWidow Browser"
                }
            }
            print("❌ Download task failed: \(error)")
        }
    }
}

