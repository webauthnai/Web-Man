//
//  DraggableTitleLabel+NSDraggingSource.swift
//  WebMan
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

extension DraggableTitleLabel: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}
