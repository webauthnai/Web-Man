//
//  DraggableFavoriteButton.swift
//  WebMan
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - DraggableFavoriteButton for Reordering
class DraggableFavoriteButton: NSButton {
    weak var delegate: DraggableFavoriteDelegate?
    var favoriteURL: String = ""
    private var originalSuperview: NSView?
    private var trackingArea: NSTrackingArea?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTrackingArea()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // No hover effects - completely flat buttons
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // No hover effects - completely flat buttons
    }
    
    override func mouseDown(with event: NSEvent) {
        let startPoint = event.locationInWindow
        var dragStarted = false
        
        window?.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: .eventTracking) { dragEvent, stop in
            guard let dragEvent = dragEvent else { return }
            
            let currentPoint = dragEvent.locationInWindow
            let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
            
            if dragEvent.type == .leftMouseDragged && distance > 5 && !dragStarted {
                dragStarted = true
                self.startReorderDrag(with: dragEvent)
                stop.pointee = true
            } else if dragEvent.type == .leftMouseUp {
                stop.pointee = true
                if !dragStarted {
                    self.performClick(nil)
                }
            }
        }
    }
    
    private func startReorderDrag(with event: NSEvent) {
        guard let stackView = superview as? NSStackView else { return }
        
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.setString("favorite_reorder", forType: .string)
        
        let titleText = title
        let textSize = titleText.size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ])
        
        let dragSize = NSSize(
            width: max(textSize.width + 12, 80), 
            height: max(textSize.height + 8, 24)
        )
        
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: dragSize), xRadius: 6, yRadius: 6).fill()
        
        let textRect = NSRect(
            x: 6,
            y: (dragSize.height - textSize.height) / 2,
            width: dragSize.width - 12,
            height: textSize.height
        )
        
        titleText.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor
        ])
        
        dragImage.unlockFocus()
        
        let dragItem = NSDraggingItem(pasteboardWriter: "favorite_reorder" as NSString)
        dragItem.setDraggingFrame(NSRect(origin: .zero, size: dragSize), contents: dragImage)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}
