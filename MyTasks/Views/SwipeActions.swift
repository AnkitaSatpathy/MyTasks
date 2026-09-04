//
//  SwipeActions.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

/// One side of a swipe: the button that appears behind the row.
struct SwipeAction {
    let title: String
    let systemImage: String
    let tint: Color
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

    /// How much of the row a button takes when it is parked open.
    private let buttonWidth: CGFloat = 84
    /// Lifting off past this share of the row fires without a second tap.
    private let fullSwipeShare: CGFloat = 0.55
    private let corner: CGFloat = 14

    @State private var offset: CGFloat = 0
    @State private var offsetAtStart: CGFloat = 0
    /// Which way the current gesture went first. A vertical one is the scroll's.
    @State private var axis: Axis?
    @State private var openSide: Side?
    @State private var width: CGFloat = 0
    @State private var isPastFullSwipe = false
    @State private var isFiring = false

    private var fullSwipeDistance: CGFloat { max(width * fullSwipeShare, buttonWidth) }

    var body: some View {
        ZStack {
            // Sit under the card, so they are revealed rather than animated in.
            if let leading {
                button(for: leading, on: .leading)
                    .opacity(offset > 0 ? 1 : 0)
            }
            button(for: trailing, on: .trailing)
                .opacity(offset < 0 ? 1 : 0)

            content
                .offset(x: offset)
                // While open, a tap anywhere on the row closes it instead of
                // reaching the card underneath.
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
        .onChange(of: isOpen) { _, open in
            // The list closed us because another row opened. Settling without
            // writing back, so this does not clear the row that just opened.
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
            .fill(action.tint)
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
                    .foregroundStyle(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
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
                // Nothing to reveal on the leading side of a Done card.
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
                    // Where the flick was heading, not just where it stopped.
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

    /// Slides the row out the way it was swiped before the action removes it.
    private func fire(_ action: SwipeAction, towards side: Side) {
        isFiring = true
        let distance = max(width, 1) + buttonWidth
        withAnimation(.snappy(duration: 0.2), completionCriteria: .logicallyComplete) {
            offset = side == .leading ? distance : -distance
        } completion: {
            action.perform()
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
                                SwipeAction(title: next.title, systemImage: "arrow.right", tint: next.tint) {
                                    withAnimation(.snappy(duration: 0.25)) {
                                        tasks.removeAll { $0.id == task.id }
                                    }
                                }
                            },
                            trailing: SwipeAction(title: "Delete", systemImage: "trash.fill", tint: .red) {
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
