//
//  SwipeActions.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

/// `Task` is this app's model, so the concurrency one needs its full name.
private typealias Job = _Concurrency.Task

/// One side of a swipe: the button that appears behind the row.
struct SwipeAction {
    let title: String
    let systemImage: String
    /// The button itself, at the edge of the row.
    let tint: Color
    /// The panel revealed behind the sliding card. Defaults to the button's
    /// own colour; give it a wash instead to let the button stand out on it.
    var panel: Color?
    /// What is drawn on the tint. A pale fill needs dark content, a strong one
    /// needs white, so the caller decides rather than the view guessing.
    var content: Color = .primary
    let perform: () -> Void
}

/// The Messages-style swipe. Drag a row left to park Delete open, right to park
/// Move open, or keep going past the halfway mark and lift off to fire the
/// action outright. Both actions take the card out of the list it is in, so the
/// row slides away in the direction it was swiped before the action runs.
///
/// The list owns `isOpen`, so opening one row closes whichever was open before.
/// A long press still belongs to the drag-and-drop reorder, so this only claims
/// a gesture once it is clearly horizontal.
struct SwipeActions<Content: View>: View {
    @Binding var isOpen: Bool
    /// Revealed by a swipe to the right. Absent on a card with nowhere to move.
    let leading: SwipeAction?
    /// Revealed by a swipe to the left.
    let trailing: SwipeAction
    private let content: Content

    init(
        isOpen: Binding<Bool>,
        leading: SwipeAction?,
        trailing: SwipeAction,
        @ViewBuilder content: () -> Content
    ) {
        _isOpen = isOpen
        self.leading = leading
        self.trailing = trailing
        self.content = content()
    }

    private enum Side { case leading, trailing }

    private let buttonWidth: CGFloat = 84
    private let fullSwipeShare: CGFloat = 0.55
    private let corner: CGFloat = 14

    @State private var offset: CGFloat = 0
    @State private var offsetAtStart: CGFloat = 0
    @State private var axis: Axis?
    @State private var openSide: Side?
    @State private var width: CGFloat = 0
    @State private var isPastFullSwipe = false
    @State private var isFiring = false

    private var fullSwipeDistance: CGFloat { max(width * fullSwipeShare, buttonWidth) }

    var body: some View {
        ZStack {
            if let leading {
                button(for: leading, on: .leading)
                    .opacity(offset > 0 ? 1 : 0)
            }
            button(for: trailing, on: .trailing)
                .opacity(offset < 0 ? 1 : 0)

            content
                .offset(x: offset)
                .overlay {
                    if openSide != nil {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { close() }
                            .offset(x: offset)
                    }
                }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            }
        }
        .gesture(swipe)
    
        .onAppear {
            guard !isOpen else { return }
            offset = 0
            openSide = nil
            isFiring = false
        }
        .onChange(of: isOpen) { _, open in
            guard !open, !isFiring, openSide != nil else { return }
            settle(to: nil)
        }
        .accessibilityActions {
            if let leading {
                Button(leading.title, action: leading.perform)
            }
            Button(trailing.title, action: trailing.perform)
        }
    }

    private func button(for action: SwipeAction, on side: Side) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(action.panel ?? action.tint)
            .overlay(alignment: side == .leading ? .leading : .trailing) {
                Button { fire(action, towards: side) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 18))
                        Text(action.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(action.content)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                    .background(action.tint, in: .rect(cornerRadius: corner, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .accessibilityHidden(true)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if axis == nil {
                    axis = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                    offsetAtStart = offset
                }
                guard axis == .horizontal else { return }

                let raw = offsetAtStart + value.translation.width
                offset = leading == nil ? min(0, raw) : raw

                let past = abs(offset) > fullSwipeDistance
                if past != isPastFullSwipe {
                    isPastFullSwipe = past
                    if past { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
                }
            }
            .onEnded { value in
                defer {
                    axis = nil
                    isPastFullSwipe = false
                }
                guard axis == .horizontal else { return }

                let side: Side = offset > 0 ? .leading : .trailing
                guard let action = self.action(on: side) else { return open(nil) }

                if abs(offset) > fullSwipeDistance {
                    fire(action, towards: side)
                } else {
                    let projected = offsetAtStart + value.predictedEndTranslation.width
                    open(abs(projected) > buttonWidth / 2 ? side : nil)
                }
            }
    }

    private func action(on side: Side) -> SwipeAction? {
        side == .leading ? leading : trailing
    }

    /// Parks the row at `side` without telling the list, so a row closing
    /// because another one opened cannot clear that other row's claim.
    private func settle(to side: Side?) {
        let target: CGFloat
        switch side {
        case .leading: target = buttonWidth
        case .trailing: target = -buttonWidth
        case .none: target = 0
        }
        withAnimation(.snappy(duration: 0.25)) { offset = target }
        openSide = side
    }

    private func open(_ side: Side?) {
        settle(to: side)
        isOpen = side != nil
    }

    private func close() { open(nil) }

    private func fire(_ action: SwipeAction, towards side: Side) {
        guard !isFiring else { return }
        isFiring = true

        let distance = max(width, 1) + buttonWidth
        withAnimation(.snappy(duration: 0.2)) {
            offset = side == .leading ? distance : -distance
        }

        Job {
            try? await Job<Never, Never>.sleep(for: .milliseconds(200))
            action.perform()
            var settled = Transaction()
            settled.disablesAnimations = true
            withTransaction(settled) {
                offset = 0
                openSide = nil
                isFiring = false
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var open: UUID?
        @State private var tasks = [
            Task(title: "Swipe me left to delete", details: "Or right to move me on."),
            Task(title: "Buy groceries", details: "Milk, bread, coffee."),
            Task(title: "Ship it", status: .done)
        ]

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(tasks) { task in
                        SwipeActions(
                            isOpen: Binding(
                                get: { open == task.id },
                                set: { open = $0 ? task.id : nil }
                            ),
                            leading: task.status.next.map { next in
                                SwipeAction(title: next.title, systemImage: "arrow.right", tint: next.tint, panel: .brandSurface) {
                                    withAnimation(.snappy(duration: 0.25)) {
                                        tasks.removeAll { $0.id == task.id }
                                    }
                                }
                            },
                            trailing: SwipeAction(title: "Delete", systemImage: "trash.fill", tint: .red, content: .white) {
                                withAnimation(.snappy(duration: 0.25)) {
                                    tasks.removeAll { $0.id == task.id }
                                }
                            }
                        ) {
                            TaskCard(task: task)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return Demo()
}
