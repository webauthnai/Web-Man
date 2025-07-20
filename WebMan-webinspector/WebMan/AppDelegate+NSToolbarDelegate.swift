//
//  App.swift
//  WebMan
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - NSToolbarDelegate
extension AppDelegate: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        
        switch itemIdentifier {
        case .backButton:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Go Back"
            item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
            item.target = self
            item.action = #selector(goBack)
            return item
            
        case .forwardButton:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Go Forward"
            item.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
            item.target = self
            item.action = #selector(goForward)
            return item
            
        case .addressBar:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = addressBarContainer
            // Sizing is now handled by Auto Layout constraints on the container view
            return item
            
        case .pageTitle:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = titleLabel
            return item
            
        case .reload:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Reload the current page"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
            item.image?.size = NSSize(width: 36, height: 24)
            item.target = self
            item.action = #selector(reloadWebView)
            return item
            
        case .dogTagManager:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.toolTip = "Manage WebAuthn Credentials"
            item.image = NSImage(systemSymbolName: "person.badge.key", accessibilityDescription: "DogTag Manager")
            item.image?.size = NSSize(width: 36, height: 24)
            item.target = self
            item.action = #selector(showDogTagManager)
            return item
            
        default:
            return nil
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .backButton,
            .forwardButton,
            .addressBar,
            .reload,
            .dogTagManager,
            .flexibleSpace,
            .pageTitle,

        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .backButton,
            .forwardButton,
            .addressBar,
            .reload,
            .dogTagManager,
            .flexibleSpace,
            .pageTitle,
        ]
    }
}

// MARK: - Toolbar Item Identifiers
extension NSToolbarItem.Identifier {
    static let backButton = NSToolbarItem.Identifier("BackButton")
    static let forwardButton = NSToolbarItem.Identifier("ForwardButton")
    static let addressBar = NSToolbarItem.Identifier("AddressBar")
    static let pageTitle = NSToolbarItem.Identifier("PageTitle")
    static let reload = NSToolbarItem.Identifier("Reload")
    static let dogTagManager = NSToolbarItem.Identifier("DogTagManager")
}

