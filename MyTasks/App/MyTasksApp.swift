//
//  MyTasksApp.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

@main
struct MyTasksApp: App {
    /// One view model, one sync engine, for the life of the app.
    @State private var viewModel: TasksViewModel

    init() {
        FirebaseRemote.configureIfPossible()
        _viewModel = State(initialValue: .live())
    }

    var body: some Scene {
        WindowGroup {
            TasksView(viewModel: viewModel)
                // The board is designed around one palette — a sticky-note
                // yellow on a pale ground — so it stays light whatever the
                // device is set to.
                .preferredColorScheme(.light)
        }
    }
}
