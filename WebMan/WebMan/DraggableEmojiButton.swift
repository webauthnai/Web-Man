//
//  DraggableEmojiButton.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - DraggableEmojiButton for Address Bar
class DraggableEmojiButton: NSButton {
    weak var addressBar: NSTextField?
    
    override func mouseDown(with event: NSEvent) {
        guard let addressBar = addressBar,
              let urlString = addressBar.stringValue as String?,
              !urlString.isEmpty,
              (urlString.hasPrefix("http") || urlString.contains(".")) else {
            super.mouseDown(with: event)
            return
        }
        
        let startPoint = event.locationInWindow
        var dragStarted = false
        
        window?.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: .eventTracking) { dragEvent, stop in
            guard let dragEvent = dragEvent else { return }
            
            let currentPoint = dragEvent.locationInWindow
            let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
            
            if dragEvent.type == .leftMouseDragged && distance > 5 && !dragStarted {
                dragStarted = true
                self.startDragOperation(with: urlString, event: dragEvent)
                stop.pointee = true
            } else if dragEvent.type == .leftMouseUp {
                stop.pointee = true
                if !dragStarted {
                    // This was just a click, perform normal action
                    self.performClick(nil)
                }
            }
        }
    }
    
    private func startDragOperation(with urlString: String, event: NSEvent) {
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.setString("emoji_bookmark_add:\(urlString)", forType: .string)
        
        // Create PROPER drag image with SF Symbol and URL
        let truncatedURL = urlString.count > 18 ? String(urlString.prefix(18)) + "..." : urlString
        let textSize = truncatedURL.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ])
        
        let iconSize: CGFloat = 14
        let spacing: CGFloat = 6
        let padding: CGFloat = 8
        
        let dragSize = NSSize(
            width: max(iconSize + spacing + textSize.width + padding * 2, 100),
            height: max(iconSize + padding, 26)
        )
        
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        
        // Draw background only - no border
        NSColor.systemBlue.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: dragSize), xRadius: 6, yRadius: 6).fill()
        
        // Draw SF Symbol link icon
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        if let linkIcon = NSImage(systemSymbolName: "link", accessibilityDescription: "Link")?.withSymbolConfiguration(config) {
            linkIcon.isTemplate = true
            let iconRect = NSRect(
                x: padding,
                y: (dragSize.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            // Draw icon with blue tint
            NSColor.systemBlue.set()
            linkIcon.draw(in: iconRect)
        }
        
        // Draw URL text next to icon
        let textRect = NSRect(
            x: padding + iconSize + spacing,
            y: (dragSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        truncatedURL.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.systemBlue
        ])
        
        dragImage.unlockFocus()
        
        let dragItem = NSDraggingItem(pasteboardWriter: "emoji_bookmark_add:\(urlString)" as NSString)
        dragItem.setDraggingFrame(NSRect(origin: .zero, size: dragSize), contents: dragImage)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}
