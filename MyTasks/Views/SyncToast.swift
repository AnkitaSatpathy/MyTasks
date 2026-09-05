//
//  SyncToast.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import SwiftUI

/// Something worth saying once about the sync, and then not again.
struct SyncNotice: Equatable {
    enum Tone {
        case progress
        case success
        case neutral
        case failure
    }

    let text: String
    let symbol: String
    let tone: Tone
}

/// The sync message as a pill over the board: it drops in from the top, says
/// its piece and leaves. Nothing here lingers, so the board is never covered
/// by a message the user has already read.
struct SyncToast: View {
    let notice: SyncNotice?

    var body: some View {
        VStack {
            if let notice {
                pill(notice)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: notice)
    }

    private func pill(_ notice: SyncNotice) -> some View {
        HStack(spacing: 7) {
            if notice.tone == .progress {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: notice.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint(notice.tone))
            }

            Text(notice.text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(notice.tone == .neutral ? Color.primary : tint(notice.tone))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: .capsule)
        .overlay {
            Capsule().strokeBorder(tint(notice.tone).opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func tint(_ tone: SyncNotice.Tone) -> Color {
        switch tone {
        case .progress, .neutral: .secondary
        case .success: .green
        case .failure: .red
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        SyncToast(notice: SyncNotice(text: "All changes synced", symbol: "checkmark.icloud", tone: .success))
        SyncToast(notice: SyncNotice(text: "Syncing 1 change…", symbol: "", tone: .progress))
        SyncToast(notice: SyncNotice(text: "Offline", symbol: "wifi.slash", tone: .neutral))
        SyncToast(notice: SyncNotice(text: "Couldn't sync 2 changes", symbol: "exclamationmark.icloud.fill", tone: .failure))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
