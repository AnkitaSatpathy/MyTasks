//
//  TasksView.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct TasksView: View {
    @State private var viewModel: TasksViewModel
    @State private var status: TaskStatus = .todo
    /// Only one row keeps its swipe actions open at a time.
    @State private var swiped: UUID?
    @State private var newTask: Task?
    @State private var editedTask: Task?

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
            .onChange(of: status) { _, _ in swiped = nil }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Task", systemImage: "plus") {
                        swiped = nil
                        newTask = Task(status: status)
                    }
                }
            }
            .sheet(item: $newTask) { task in
                TaskEditorView(task: task, isNew: true) { viewModel.add($0) }
            }
            .sheet(item: $editedTask) { task in
                TaskEditorView(task: task, isNew: false) { viewModel.update($0) }
            }
        }
    }

    private var cards: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(visibleTasks) { task in
                    SwipeActions(
                        isOpen: swipeBinding(for: task),
                        leading: task.status.next.map { next in
                            SwipeAction(title: next.title, systemImage: "arrow.right", tint: next.tint) {
                                advance(task)
                            }
                        },
                        trailing: SwipeAction(title: "Delete", systemImage: "trash.fill", tint: .red) {
                            delete(task)
                        }
                    ) {
                        TaskCard(
                            task: task,
                            onTap: { edit(task) },
                            onAdvance: { advance(task) }
                        )
                    }
                    .draggable(task.id.uuidString) {
                        TaskCard(task: task).frame(width: 280)
                    }
                    .onDrop(of: [.text], delegate: MoveDropDelegate { id in
                        reorder(id, above: task)
                    })
                }

               
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .contentShape(.rect)
                    .onDrop(of: [.text], delegate: MoveDropDelegate { id in
                        reorder(id, above: nil)
                    })
            }
            .padding(.horizontal, 16)
        }
        .onTapGesture { swiped = nil }
        // A scroll puts the open row away, the way Mail does. Only a vertical
        // drag counts, so this never fights the horizontal swipe itself.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onChanged { value in
                guard swiped != nil,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                swiped = nil
            }
        )
    }

    // MARK: - Swiping

    /// A row claims the single open slot, which closes whichever row held it.
    private func swipeBinding(for task: Task) -> Binding<Bool> {
        Binding(
            get: { swiped == task.id },
            set: { isOpen in swiped = isOpen ? task.id : nil }
        )
    }

    // MARK: - Actions

    private func advance(_ task: Task) {
        withAnimation(.snappy(duration: 0.25)) {
            swiped = nil
            viewModel.advance(task)
        }
    }

    private func delete(_ task: Task) {
        withAnimation(.snappy(duration: 0.25)) {
            swiped = nil
            viewModel.delete(task)
        }
    }

    /// Tapping a card opens it in the editor sheet.
    private func edit(_ task: Task) {
        swiped = nil
        editedTask = task
    }

    private func reorder(_ id: UUID, above task: Task?) {
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
        Task(title: "Design the board layout", details: "Tap a card to edit it."),
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
