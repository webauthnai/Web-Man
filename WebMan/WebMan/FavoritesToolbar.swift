//
//  FavoritesToolbar.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

class FavoritesToolbar: NSView {
    weak var delegate: FavoritesToolbarDelegate?
    var stackView: NSStackView?
    var scrollView: NSScrollView?
    var trashCan: TrashCanView?
    private var insertionIndex: Int = -1
    private var originalSpacing: CGFloat = 8
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupDragAndDrop()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        // Register for URL drops and favorite reordering
        registerForDraggedTypes([.URL, .string])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.URL.rawValue, NSPasteboard.PasteboardType.string.rawValue]) else {
            return []
        }
        
        let pasteboard = sender.draggingPasteboard
        
        // Check if this is a reorder operation
        if let stringValue = pasteboard.string(forType: .string), stringValue == "favorite_reorder" {
            return .move
        } else if let stringValue = pasteboard.string(forType: .string), 
                  stringValue.hasPrefix("emoji_bookmark_add:") {
            return .copy
        } else {
            return []
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let stringValue = sender.draggingPasteboard.string(forType: .string),
              let _ = stackView else {
            return draggingEntered(sender)
        }
        
        if stringValue == "favorite_reorder" {
            let dropLocation = convert(sender.draggingLocation, from: nil)
            let newInsertionIndex = calculateInsertionIndex(at: dropLocation)
            
            if newInsertionIndex != insertionIndex {
                updateInsertionPoint(to: newInsertionIndex)
            }
            
            return .move
        } else if stringValue.hasPrefix("emoji_bookmark_add:") {
            let dropLocation = convert(sender.draggingLocation, from: nil)
            let newInsertionIndex = calculateInsertionIndex(at: dropLocation)
            
            if newInsertionIndex != insertionIndex {
                updateInsertionPoint(to: newInsertionIndex)
            }
            
            return .copy
        }
        
        return draggingEntered(sender)
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearInsertionPoint()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        clearInsertionPoint()
        
        let pasteboard = sender.draggingPasteboard
        
        if let stringValue = pasteboard.string(forType: .string), stringValue == "favorite_reorder" {
            return handleFavoriteReorder(sender)
        } else if let dragString = pasteboard.string(forType: .string),
                  dragString.hasPrefix("emoji_bookmark_add:") {
            let urlString = String(dragString.dropFirst("emoji_bookmark_add:".count))
            if let url = URL(string: urlString) {
                let siteName = url.host?.replacingOccurrences(of: "www.", with: "") ?? "New Site"
                let displayName = "🕷️ \(siteName.capitalized)"
                
                // Calculate insertion index fresh from current drop location
                let dropLocation = convert(sender.draggingLocation, from: nil)
                let targetIndex = calculateInsertionIndex(at: dropLocation)
                
                print("🎯 EMOJI DROP: Calculated insertion index: \(targetIndex)")
                delegate?.addFavoriteAtIndex(name: displayName, url: urlString, index: targetIndex)
                
                // Extra save to ensure persistence after drag
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let appDelegate = self.delegate as? AppDelegate {
                        appDelegate.saveFavoritesToUserDefaults()
                    }
                }
                return true
            }
        }
        
        return false
    }
    
    private func handleFavoriteReorder(_ sender: NSDraggingInfo) -> Bool {
        guard let stackView = stackView else { return false }
        
        let dropLocation = convert(sender.draggingLocation, from: nil)
        var targetIndex = 0
        
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            if view is DraggableFavoriteButton {
                let buttonFrame = view.frame
                if dropLocation.x < buttonFrame.midX {
                    targetIndex = index
                    break
                }
                targetIndex = index + 1
            }
        }
        
        var sourceIndex = -1
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            if let button = view as? DraggableFavoriteButton, button.alphaValue < 1.0 {
                sourceIndex = index
                break
            }
        }
        
        if sourceIndex >= 0 && sourceIndex != targetIndex {
            delegate?.reorderFavorite(from: sourceIndex, to: targetIndex)
            
            // Extra save to ensure persistence after drag reorder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let appDelegate = self.delegate as? AppDelegate {
                    appDelegate.saveFavoritesToUserDefaults()
                }
            }
            return true
        }
        
        return false
    }
    
    private func calculateInsertionIndex(at location: NSPoint) -> Int {
        guard let stackView = stackView else { 
            print("🎯 No stackView found")
            return 0 
        }
        
        var insertionIndex = 0
        
        // Convert location directly to stackView's coordinate system
        let localLocation = stackView.convert(location, from: self)
        print("🎯 Drop location: \(location) -> Local: \(localLocation)")
        print("🎯 StackView frame: \(stackView.frame)")
        print("🎯 StackView bounds: \(stackView.bounds)")
        
        let favoriteButtons = stackView.arrangedSubviews.compactMap { $0 as? DraggableFavoriteButton }
        print("🎯 Found \(favoriteButtons.count) favorite buttons")
        
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            guard view is DraggableFavoriteButton else { continue }
            
            let buttonFrame = view.frame
            let buttonCenter = buttonFrame.midX
            
            print("🎯 Button \(index): frame=\(buttonFrame), center=\(buttonCenter), dropX=\(localLocation.x)")
            
            if localLocation.x < buttonCenter {
                insertionIndex = index
                print("🎯 Inserting at index \(index) (before button)")
                break
            }
            insertionIndex = index + 1
            print("🎯 Continuing... insertionIndex now \(insertionIndex)")
        }
        
        print("🎯 Final insertion index: \(insertionIndex)")
        return insertionIndex
    }
    
    private func updateInsertionPoint(to newIndex: Int) {
        guard let stackView = stackView else { return }
        guard newIndex != insertionIndex else { return }
        
        print("🎯 Updating insertion point to index: \(newIndex)")
        
        // Clear previous insertion point
        clearInsertionPoint()
        
        // Set new insertion index
        insertionIndex = newIndex
        
        // Create visual gap with SMOOTH animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                guard view is DraggableFavoriteButton else { continue }
                
                // Special handling for different insertion positions
                if insertionIndex == 0 && index == 0 {
                    // Inserting at the very beginning - add spacing before first item
                    continue
                } else if index == insertionIndex - 1 {
                    // Add extra spacing after the view that comes before insertion point
                    stackView.setCustomSpacing(originalSpacing + 20, after: view)
                    print("🎯 Added gap after button at index \(index)")
                } else {
                    // Normal spacing
                    stackView.setCustomSpacing(originalSpacing, after: view)
                }
            }
            
            // For insertion at beginning, adjust scroll view content insets
            if insertionIndex == 0, let scrollView = scrollView {
                scrollView.contentInsets.left = 20
                print("🎯 Added gap at beginning")
            }
        }
    }
    
    private func clearInsertionPoint() {
        guard let stackView = stackView else { return }
        guard insertionIndex != -1 else { return }
        
        let wasInsertingAtStart = (insertionIndex == 0)
        insertionIndex = -1
        
        // Restore original spacing with SMOOTH animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            for view in stackView.arrangedSubviews {
                guard view is DraggableFavoriteButton else { continue }
                stackView.setCustomSpacing(originalSpacing, after: view)
            }
            
            // Reset scroll view content insets if we were inserting at start
            if wasInsertingAtStart, let scrollView = scrollView {
                scrollView.contentInsets.left = 0
            }
        }
    }
}
