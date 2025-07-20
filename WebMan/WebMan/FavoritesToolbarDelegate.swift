//
//  FavoritesToolbarDelegate.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - FavoritesToolbar with Drag and Drop
protocol FavoritesToolbarDelegate: AnyObject {
    func addFavorite(name: String, url: String)
    func addFavoriteAtIndex(name: String, url: String, index: Int)
    func reorderFavorite(from sourceIndex: Int, to destinationIndex: Int)
    func deleteFavorite(at index: Int)
}

protocol DraggableFavoriteDelegate: AnyObject {
    func favoriteWantsToMove(_ button: DraggableFavoriteButton, to location: NSPoint)
}

protocol TrashCanDelegate: AnyObject {
    func deleteFavorite(at index: Int)
}
