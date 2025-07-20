//
//  DogTagWindow.swift
//  WebMan
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa
import SwiftUI
import DogTagClient

// MARK: - DogTag Window
class DogTagWindow: NSWindow {
    weak var appDelegate: AppDelegate?
    public var hostingView: NSView?
    
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
    
    public func setupSwiftUIContent() {
        // Create the hosting view with DogTagManager
        let hostingView = NSHostingView(rootView: DogTagManager())
        self.hostingView = hostingView
        self.contentView = hostingView
    }
    
    public func cleanupSwiftUIContent() {
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
