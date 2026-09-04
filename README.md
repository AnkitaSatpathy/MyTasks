# MyTasks

iOS task management application that allows users to organize tasks across a
simple workflow. SwiftUI, iOS 17+. Open `MyTasks.xcodeproj` and run.

The three statuses — To Do, In Progress, Done — sit as pills under the title,
each showing how many tasks it holds. Tapping one filters the list below it.
Tasks are stored as JSON in the app's Documents directory, so the app is fully
usable offline.

| Action | How |
| --- | --- |
| Create | **+** in the top right (lands in the selected list) |
| Expand | Tap a card — it opens in place, no sheet |
| Edit | Expand → **Edit** |
| Delete | Expand → **Delete** |
| Move on one step | The **→** button on the card (To Do → In Progress → Done) |
| Move anywhere | Expand → **Move**, or drag the card onto a status pill |
| Reorder | Long press a card and drag it above another |

A long press is always a drag — there is no context menu, so the gesture only
ever reorders a card or drops it on a pill.

## Structure

```
MyTasks.xcodeproj
MyTasks/
├── App/          MyTasksApp.swift          entry point
├── Models/       Task.swift                id, title, description, status, dates
│                 TaskStatus.swift          the three statuses
├── Services/     TaskRepository.swift      protocol + JSON and in-memory stores
├── ViewModels/   TasksViewModel.swift      task state, CRUD, move, reorder
│                 TaskEditorViewModel.swift the draft being edited, validation
└── Views/        TasksView.swift           the filtered list and its toolbar
                  StatusFilterBar.swift     the three status pills, also drop targets
                  TaskCard.swift            a single card, collapsed or expanded
                  TaskEditorView.swift      the create/edit sheet
                  TaskStatus+Style.swift    icon and tint per status
```

The views hold no logic beyond layout, the view models hold no SwiftUI, and the
models are plain `Codable` values. `TaskRepository` is a protocol so the Xcode
previews run against `InMemoryTaskRepository` instead of writing to disk.

The tasks live in one flat array; a status is a filtered slice of it, so a
task's position within its status is just its relative position in that array.
