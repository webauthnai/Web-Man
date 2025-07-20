//
//  DraggableTitleLabel+NSTextField.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - DraggableTitleLabel for Website Title
class DraggableTitleLabel: NSTextField {
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
                    // This was just a click, handle normally
                    super.mouseDown(with: event)
                }
            }
        }
    }
    
    private func startDragOperation(with urlString: String, event: NSEvent) {
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.setString("emoji_bookmark_add:\(urlString)", forType: .string)
        
        // Create drag image with page title and URL
        let pageTitle = self.stringValue.isEmpty ? "Webpage" : self.stringValue
        let truncatedTitle = pageTitle.count > 20 ? String(pageTitle.prefix(20)) + "..." : pageTitle
        let truncatedURL = urlString.count > 18 ? String(urlString.prefix(18)) + "..." : urlString
        
        let titleSize = truncatedTitle.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ])
        let urlSize = truncatedURL.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular)
        ])
        
        let padding: CGFloat = 8
        let lineSpacing: CGFloat = 2
        
        let dragSize = NSSize(
            width: max(titleSize.width, urlSize.width) + padding * 2,
            height: titleSize.height + urlSize.height + lineSpacing + padding * 2
        )
        
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        
        // Draw background
        NSColor.systemBlue.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: dragSize), xRadius: 6, yRadius: 6).fill()
        
        // Draw page title
        let titleRect = NSRect(
            x: padding,
            y: padding + urlSize.height + lineSpacing,
            width: titleSize.width,
            height: titleSize.height
        )
        
        truncatedTitle.draw(in: titleRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.systemBlue
        ])
        
        // Draw URL
        let urlRect = NSRect(
            x: padding,
            y: padding,
            width: urlSize.width,
            height: urlSize.height
        )
        
        truncatedURL.draw(in: urlRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.systemBlue.withAlphaComponent(0.7)
        ])
        
        dragImage.unlockFocus()
        
        let dragItem = NSDraggingItem(pasteboardWriter: "emoji_bookmark_add:\(urlString)" as NSString)
        dragItem.setDraggingFrame(NSRect(origin: .zero, size: dragSize), contents: dragImage)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}
