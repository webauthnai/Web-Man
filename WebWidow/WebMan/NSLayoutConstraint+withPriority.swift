//
//  NSLayoutConstraint+withPriority.swift
//  WebWidow
//
//  Created by FIDO3.ai / WebAuthn.AI on 7/20/25.
//

import Cocoa

// MARK: - NSLayoutConstraint Priority Extension
extension NSLayoutConstraint {
    func withPriority(_ priority: NSLayoutConstraint.Priority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
