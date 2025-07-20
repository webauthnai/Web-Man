//
//  BrowserManager+WKUIDelegate.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Foundation

// MARK: - URLSessionDownloadDelegate
extension BrowserManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
            self.downloadStatus = "Downloading... \(Int(progress * 100))%"
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
                self.downloadProgress = 1.0
                self.downloadStatus = "Download completed successfully!"
                
                // Clear status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.downloadStatus = ""
                    self.downloadProgress = 0.0
                }
            }
            
            print("✅ Download completed: \(destinationURL.path)")
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadStatus = "Download failed: \(error.localizedDescription)"
                
                // Clear status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.downloadStatus = ""
                    self.downloadProgress = 0.0
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
                self.downloadStatus = "Download failed: \(error.localizedDescription)"
                
                // Clear status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.downloadStatus = ""
                    self.downloadProgress = 0.0
                }
            }
            print("❌ Download task failed: \(error)")
        }
    }
} 
