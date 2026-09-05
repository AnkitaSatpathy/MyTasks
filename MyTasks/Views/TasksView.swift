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
    @State private var swiped: UUID?
    @State private var isSearching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var cardWidth: CGFloat = 0
    @State private var newTask: Task?
    @State private var editedTask: Task?

    init(viewModel: TasksViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var visibleTasks: [Task] {
        let inList = viewModel.tasks(in: status)
        guard isSearching else { return inList }

        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return inList }

        return inList.filter {
            $0.title.localizedCaseInsensitiveContains(wanted)
                || $0.details.localizedCaseInsensitiveContains(wanted)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                StatusFilterBar(
                    selection: $status,
                    count: { viewModel.tasks(in: $0).count },
                    onDrop: { id, target in viewModel.drop(id, above: nil, in: target) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, isSearching ? 10 : 12)

                if isSearching {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                Group {
                    if visibleTasks.isEmpty {
                        emptyState.frame(maxHeight: .infinity)
                    } else {
                        cards
                    }
                }
                
                .overlay(alignment: .top) {
                    SyncToast(notice: viewModel.syncNotice)
                    .padding(.horizontal, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: status) { _, _ in swiped = nil }
            .task { viewModel.start() }
            .sheet(item: $newTask) { task in
                TaskEditorView(task: task, isNew: true) { created in
                    withAnimation(.snappy(duration: 0.25)) {
                        viewModel.add(created)
                        status = created.status
                    }
                }
            }
            .sheet(item: $editedTask) { task in
                TaskEditorView(
                    task: task,
                    isNew: false,
                    onSave: { save($0) },
                    onDelete: { delete(task) },
                    onAdvance: { advance(task) }
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("My Tasks")
                .font(.largeTitle.bold())

            Spacer()

            circleButton("magnifyingglass", label: "Search Tasks") {
                swiped = nil
                withAnimation(.snappy(duration: 0.25)) { isSearching = true }
                searchFocused = true
            }

            circleButton("plus", label: "New Task") {
                swiped = nil
                newTask = Task(status: status)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    private func circleButton(
        _ systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(status.tint, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tasks", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button {
                        query = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: .capsule)

            Button("Cancel") {
                searchFocused = false
                withAnimation(.snappy(duration: 0.25)) {
                    isSearching = false
                    query = ""
                }
            }
            .font(.subheadline.weight(.medium))
        }
    }

    private var cards: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleTasks) { task in
                    SwipeActions(
                        isOpen: swipeBinding(for: task),
                        leading: task.status.next.map { next in
                            SwipeAction(title: next.title, systemImage: "arrow.right", tint: next.tint, panel: .brandSurface) {
                                advance(task)
                            }
                        },
                        trailing: SwipeAction(title: "Delete", systemImage: "trash.fill", tint: .red, content: .white) {
                            delete(task)
                        }
                    ) {
                        TaskCard(
                            task: task,
                            onTap: { edit(task) },
                            onAdvance: { advance(task) }
                        )
                    }
                   
                    .id(task.id)
                    .draggable(task.id.uuidString) {
                        TaskCard(task: task)
                            .frame(width: cardWidth > 0 ? cardWidth : 320)
                    }
                    .padding(.bottom, 10)
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
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { cardWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in cardWidth = width }
                }
            }
            .padding(.horizontal, 16)
        }
        .onTapGesture { swiped = nil }
        .refreshable { await viewModel.refresh() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onChanged { value in
                guard swiped != nil,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                swiped = nil
            }
        )
    }

    // MARK: - Swiping

    private func swipeBinding(for task: Task) -> Binding<Bool> {
        Binding(
            get: { swiped == task.id },
            set: { isOpen in swiped = isOpen ? task.id : nil }
        )
    }

    // MARK: - Actions

    private func advance(_ task: Task) {
        let destination = task.status.next

        withAnimation(.snappy(duration: 0.25)) {
            swiped = nil
            viewModel.advance(task)
            if let destination { status = destination }
        }
    }

    private func delete(_ task: Task) {
        withAnimation(.snappy(duration: 0.25)) {
            swiped = nil
            viewModel.delete(task)
        }
    }

    private func save(_ edited: Task) {
        withAnimation(.snappy(duration: 0.25)) {
            viewModel.update(edited)
            status = edited.status
        }
    }

    /// Tapping a card opens it in the editor sheet.
    private func edit(_ task: Task) {
        swiped = nil
        editedTask = task
    }

    private func reorder(_ id: UUID, above task: Task?) {
        guard !isSearching else { return }

        withAnimation(.snappy(duration: 0.25)) {
            viewModel.drop(id, above: task, in: status)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isSearching {
            ContentUnavailableView {
                Text(query.isEmpty ? "Search \(status.title)" : "No Results")
            } description: {
                Text(query.isEmpty
                     ? "Find a task in this list by name or description."
                     : "Nothing in \(status.title) matches “\(query)”.")
                    .padding(.top, 6)
            }
        } else if viewModel.isEmpty {
            ContentUnavailableView {
                Text("No Tasks Yet")
            } description: {
                Text("Tap + to create your first task.")
                    .padding(.top, 6)
            }
        } else {
            ContentUnavailableView {
                Text("Nothing in \(status.title)")
            } description: {
                Text("Tap + to add one, or drag a task onto this pill.")
                    .padding(.top, 6)
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
    return TasksView(viewModel: TasksViewModel(repository: InMemoryTaskRepository(tasks: tasks), remote: UnconfiguredRemoteTaskService()))
}

#Preview("Empty") {
    TasksView(viewModel: TasksViewModel(repository: InMemoryTaskRepository(), remote: UnconfiguredRemoteTaskService()))
}
