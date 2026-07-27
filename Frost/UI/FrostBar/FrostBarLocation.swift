//
//  FrostBarLocation.swift
//  Frost
//

import SwiftUI

/// Locations where the Frost Bar can appear.
enum FrostBarLocation: Int, CaseIterable, Identifiable {
    /// The Frost Bar will appear in different locations based on context.
    case dynamic = 0

    /// The Frost Bar will appear centered below the mouse pointer.
    case mousePointer = 1

    /// The Frost Bar will appear centered below the Frost icon.
    case frostIcon = 2

    var id: Int { rawValue }

    /// Localized string key representation.
    var localized: LocalizedStringKey {
        switch self {
        case .dynamic: "Dynamic"
        case .mousePointer: "Mouse pointer"
        case .frostIcon: "Frost icon"
        }
    }
}
