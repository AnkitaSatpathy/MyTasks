//
//  TasksView.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

struct TasksView: View {
    @State private var viewModel: TasksViewModel
    @State private var status: TaskStatus = .todo
    @State private var expanded: UUID?
    @State private var draftTitle = ""
    @State private var draftDetails = ""
    @State private var newTask: Task?

    init(viewModel: TasksViewModel = TasksViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    private var visibleTasks: [Task] { viewModel.tasks(in: status) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusFilterBar(
                    selection: $status,
                    count: { viewModel.tasks(in: $0).count },
                    onDrop: { id, target in viewModel.drop(id, above: nil, in: target) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if visibleTasks.isEmpty {
                    emptyState.frame(maxHeight: .infinity)
                } else {
                    cards
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Task", systemImage: "plus") {
                        collapse()
                        newTask = Task(status: status)
                    }
                }
            }
            .sheet(item: $newTask) { task in
                TaskEditorView(task: task, isNew: true) { viewModel.add($0) }
            }
        }
    }

    private var cards: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(visibleTasks) { task in
                    TaskCard(
                        task: task,
                        isExpanded: expanded == task.id,
                        title: $draftTitle,
                        details: $draftDetails,
                        onExpand: { expand(task) },
                        onSubmit: { collapse() },
                        onAdvance: { advance(task) },
                        onMove: { move(task, to: $0) },
                        onDelete: { delete(task) }
                    )
                    
                    .draggable(task.id.uuidString) {
                        TaskCard(task: task).frame(width: 280)
                    }
                    .dropDestination(for: String.self) { ids, _ in
                        reorder(ids, above: task)
                    }
                }

               
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .contentShape(.rect)
                    .dropDestination(for: String.self) { ids, _ in
                        reorder(ids, above: nil)
                    }
            }
            .padding(.horizontal, 16)
        }
        .scrollDismissesKeyboard(.interactively)
       
        .onTapGesture { collapse() }
    }

    // MARK: - Editing

    private func expand(_ task: Task) {
        commitDraft()
        draftTitle = task.title
        draftDetails = task.details
        withAnimation(.snappy(duration: 0.25)) {
            expanded = task.id
        }
    }

    private func collapse() {
        guard expanded != nil else { return }
        commitDraft()
        withAnimation(.snappy(duration: 0.25)) {
            expanded = nil
        }
    }

   
    private func commitDraft() {
        guard let id = expanded,
              var task = viewModel.tasks.first(where: { $0.id == id }) else { return }

        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = draftDetails.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, title != task.title || details != task.details else { return }

        task.title = title
        task.details = details
        viewModel.update(task)
    }

    // MARK: - Actions

    private func advance(_ task: Task) {
        withAnimation(.snappy(duration: 0.25)) {
            viewModel.advance(task)
        }
    }

    private func move(_ task: Task, to newStatus: TaskStatus) {
        commitDraft()
        withAnimation(.snappy(duration: 0.25)) {
            expanded = nil
            viewModel.move(task, to: newStatus)
        }
    }

    private func delete(_ task: Task) {
        withAnimation(.snappy(duration: 0.25)) {
            expanded = nil
            viewModel.delete(task)
        }
    }

    private func reorder(_ ids: [String], above task: Task?) {
        guard let id = ids.first.flatMap(UUID.init) else { return }
        withAnimation(.snappy(duration: 0.25)) {
            viewModel.drop(id, above: task, in: status)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isEmpty {
            ContentUnavailableView {
                Text("No Tasks Yet")
            } description: {
                Text("Tap + to create your first task.")
            }
        } else {
            ContentUnavailableView {
                Label("Nothing in \(status.title)", systemImage: status.icon)
            } description: {
                Text("Tap + to add one, or drag a task onto this pill.")
            }
        }
    }
}

#Preview("Tasks") {
    let tasks = [
        Task(title: "Design the board layout", details: "Tap a card to edit it in place."),
        Task(title: "Buy groceries", details: "Milk, bread, coffee."),
        Task(title: "Book the dentist"),
        Task(title: "Write the persistence layer", status: .inProgress),
        Task(title: "Set up the Xcode project", status: .done)
    ]
    return TasksView(viewModel: TasksViewModel(repository: InMemoryTaskRepository(tasks: tasks)))
}

#Preview("Empty") {
    TasksView(viewModel: TasksViewModel(repository: InMemoryTaskRepository()))
}
