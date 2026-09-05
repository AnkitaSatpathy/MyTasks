//
//  TaskStatus+Style.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

extension TaskStatus {
    var icon: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        }
    }

    var tint: Color { .brand }
}
