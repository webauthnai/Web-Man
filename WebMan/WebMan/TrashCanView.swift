//
//  TrashCanView.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - TrashCanView for Bookmark Deletion
class TrashCanView: NSView {
    weak var delegate: TrashCanDelegate?
    private var isHighlighted = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTrashCan()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrashCan()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrashCan()
    }
    
    private func setupTrashCan() {
        registerForDraggedTypes([.string])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw trash can icon
        let iconSize: CGFloat = 16
        let iconRect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        let color = isHighlighted ? NSColor.systemRed : NSColor.tertiaryLabelColor
        
        // Simple trash can drawing
        color.setStroke()
        color.setFill()
        
        let path = NSBezierPath()
        // Trash can body
        path.move(to: NSPoint(x: iconRect.minX + 3, y: iconRect.minY + 2))
        path.line(to: NSPoint(x: iconRect.maxX - 3, y: iconRect.minY + 2))
        path.line(to: NSPoint(x: iconRect.maxX - 4, y: iconRect.maxY - 4))
        path.line(to: NSPoint(x: iconRect.minX + 4, y: iconRect.maxY - 4))
        path.close()
        
        // Trash can lid
        let lidPath = NSBezierPath()
        lidPath.move(to: NSPoint(x: iconRect.minX + 2, y: iconRect.maxY - 3))
        lidPath.line(to: NSPoint(x: iconRect.maxX - 2, y: iconRect.maxY - 3))
        
        path.lineWidth = 1.5
        lidPath.lineWidth = 1.5
        
        path.stroke()
        lidPath.stroke()
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let stringValue = sender.draggingPasteboard.string(forType: .string),
              stringValue == "favorite_reorder" else {
            return []
        }
        
        isHighlighted = true
        needsDisplay = true
        return .delete
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        needsDisplay = true
        
        guard let stringValue = sender.draggingPasteboard.string(forType: .string),
              stringValue == "favorite_reorder" else {
            return false
        }
        
        // Find the dragged button and its index
        if let toolbar = superview?.superview as? FavoritesToolbar,
           let stackView = toolbar.stackView {
            
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                if let button = view as? DraggableFavoriteButton, button.alphaValue < 1.0 {
                    delegate?.deleteFavorite(at: index)
                    return true
                }
            }
        }
        
        return false
    }
}
