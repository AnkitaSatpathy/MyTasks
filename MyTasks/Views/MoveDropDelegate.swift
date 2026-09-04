//
//  MoveDropDelegate.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// A drop target for a dragged task id.
///
/// `dropDestination(for:)` proposes a copy, which puts a green **+** badge on
/// the card being dragged. Dragging a card here only ever moves it, so this
/// proposes `.move` instead and the badge goes away.
struct MoveDropDelegate: DropDelegate {
    /// The id carried by the drag, once the drop lands.
    let onDrop: (UUID) -> Void
    /// Whether the drag is currently over this target.
    var onTargeted: ((Bool) -> Void)? = nil

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) { onTargeted?(true) }

    func dropExited(info: DropInfo) { onTargeted?(false) }

    func performDrop(info: DropInfo) -> Bool {
        onTargeted?(false)

        guard let provider = info.itemProviders(for: [.text]).first else { return false }

        _ = provider.loadObject(ofClass: String.self) { string, _ in
            guard let id = string.flatMap(UUID.init) else { return }
            DispatchQueue.main.async { onDrop(id) }
        }
        return true
    }
}
