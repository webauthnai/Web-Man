//
//  DraggableFavoriteButton+NSDraggingSource.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

extension DraggableFavoriteButton: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        alphaValue = 0.5
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        alphaValue = 1.0
    }
}
