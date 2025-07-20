//
//  AppDelegate+FavoritesToolbarDelegate.swift
//  WebMan
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - FavoritesToolbarDelegate
extension AppDelegate: FavoritesToolbarDelegate, DraggableFavoriteDelegate, TrashCanDelegate {
    func favoriteWantsToMove(_ button: DraggableFavoriteButton, to location: NSPoint) {
        // This could be used for more advanced reordering feedback if needed
    }
    
    func addFavorite(name: String, url: String) {
        print("🌟 Adding new favorite: \(name) -> \(url)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar")
            return
        }
        
        let newButton = createFavoriteButton(name: name, url: url)
        stackView.addArrangedSubview(newButton)
        
        newButton.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            newButton.alphaValue = 1
        }
        
        showTemporaryMessage("⭐️ Added to favorites!")
    }
    
    func addFavoriteAtIndex(name: String, url: String, index: Int) {
        print("🌟 Adding new favorite at index \(index): \(name) -> \(url)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar")
            return
        }
        
        print("🌟 StackView has \(stackView.arrangedSubviews.count) subviews before insertion")
        
        let newButton = createFavoriteButton(name: name, url: url)
        
        if index >= 0 && index < stackView.arrangedSubviews.count {
            print("🌟 Inserting at specific index \(index)")
            stackView.insertArrangedSubview(newButton, at: index)
        } else {
            print("🌟 Adding to end (index \(index) out of range)")
            stackView.addArrangedSubview(newButton)
        }
        
        print("🌟 StackView has \(stackView.arrangedSubviews.count) subviews after insertion")
        
        newButton.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            newButton.alphaValue = 1
        }
        
        // Save favorites to UserDefaults
        print("🌟 About to save favorites after adding new one...")
        saveFavoritesToUserDefaults()
        
        showTemporaryMessage("⭐️ Added to favorites!")
    }
    
    func reorderFavorite(from sourceIndex: Int, to destinationIndex: Int) {
        print("🔄 Reordering favorite from \(sourceIndex) to \(destinationIndex)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar for reordering")
            return
        }
        
        let arrangedSubviews = stackView.arrangedSubviews
        guard sourceIndex < arrangedSubviews.count,
              destinationIndex <= arrangedSubviews.count,
              let sourceView = arrangedSubviews[sourceIndex] as? DraggableFavoriteButton else {
            print("❌ Invalid reorder indices")
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            stackView.removeArrangedSubview(sourceView)
            
            let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
            stackView.insertArrangedSubview(sourceView, at: adjustedDestination)
            
            sourceView.alphaValue = 1.0
        }
        
        // Save favorites to UserDefaults after reordering
        print("↔️ About to save favorites after reordering...")
        saveFavoritesToUserDefaults()
        
        showTemporaryMessage("↔️ Favorites reordered!")
    }
    
    func deleteFavorite(at index: Int) {
        print("🗑️ Deleting favorite at index \(index)")
        
        // Get reference to the toolbar from titlebar accessory
        guard let toolbar = findFavoritesToolbar(),
              let stackView = toolbar.stackView else {
            print("❌ Could not find favorites toolbar for deletion")
            return
        }
        
        let arrangedSubviews = stackView.arrangedSubviews
        guard index < arrangedSubviews.count,
              let buttonToDelete = arrangedSubviews[index] as? DraggableFavoriteButton else {
            print("❌ Invalid deletion index or button not found")
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            buttonToDelete.alphaValue = 0
            buttonToDelete.layer?.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        } completionHandler: {
            stackView.removeArrangedSubview(buttonToDelete)
            buttonToDelete.removeFromSuperview()
            
            // Save favorites to UserDefaults after deletion
            print("🗑️ About to save favorites after deletion...")
            self.saveFavoritesToUserDefaults()
        }
        
        showTemporaryMessage("🗑️ Bookmark deleted!")
    }
    
    public func showTemporaryMessage(_ message: String) {
        let originalTitle = window.title
        window.title = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.window.title = originalTitle
        }
    }
}
