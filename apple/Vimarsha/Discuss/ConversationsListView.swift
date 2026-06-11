import SwiftUI

/// The chapter's saved-conversation persistence handles (V35), bundled so the panel
/// doesn't hold the store: list (newest first), save the live conversation (each Save
/// inserts a NEW thread; `false` = nothing to save), delete one thread.
@MainActor
struct DiscussArchive {
    var threads: () -> [ChatThread]
    var save: () -> Bool
    var deleteThread: (ChatThread) -> Void
}

/// The Conversations state of the Discuss panel (V35; apple/CLAUDE.md §UI map state 7):
/// saved threads as a morphed list state of the SAME plane — never a separate screen.
/// Matte paper rows (content) on the glass plane; reopen is read-only, delete is the
/// row's only other action (threads are user content — the confirm posture matches
/// Notes: a single explicit tap on an explicit trash affordance).
struct ConversationsListView: View {
    /// Newest first (`LibraryStore.chatThreads`).
    let threads: [ChatThread]
    var onOpen: ((ChatThread) -> Void)?
    var onDelete: ((ChatThread) -> Void)?

    @ScaledMetric(relativeTo: .footnote) private var bodySize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var metaSize: CGFloat = 10

    var body: some View {
        if threads.isEmpty {
            Text("No saved conversations yet — Save keeps one.")
                .font(.system(size: bodySize))
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 12) {
                ForEach(threads, id: \.id) { thread in
                    row(thread)
                }
            }
        }
    }

    private func row(_ thread: ChatThread) -> some View {
        Button {
            onOpen?(thread)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(thread.title?.isEmpty == false ? thread.title! : "Conversation")
                    .font(.system(size: bodySize, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Text(meta(for: thread))
                        .font(.system(size: metaSize, weight: .medium).monospacedDigit())
                        .foregroundStyle(Palette.textPrimary.opacity(0.55))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary.opacity(0.4))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Palette.textPrimary.opacity(0.08), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open conversation: \(thread.title ?? "untitled")")
        .overlay(alignment: .topTrailing) {
            Button {
                onDelete?(thread)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Delete conversation")
        }
    }

    private func meta(for thread: ChatThread) -> String {
        let turns = thread.lines.count
        let date = thread.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(turns) turn\(turns == 1 ? "" : "s") · \(date)"
    }
}

#Preview("Conversations — dark") {
    let thread = ChatThread(chapterIndex: 0, title: "What does the passage claim about good design?")
    thread.lines = [
        ChatLine(role: "user", text: "Q", index: 0),
        ChatLine(role: "assistant", text: "A", index: 1),
    ]
    return ConversationsListView(threads: [thread])
        .padding(20)
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
}
