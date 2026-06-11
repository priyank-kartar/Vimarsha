import SwiftUI

/// The Notes state (V30; apple/CLAUDE.md §UI map state 5) — the open chapter's voice
/// memos as a **morphed list state of the reading surface** (never a sheet; the
/// FiguresGallery precedent): the paper body reflows into matte memo rows on the same
/// canvas. Content is paper; only the row actions are glass-adjacent controls.
struct MemoNotesView: View {
    /// Newest first (`MemoNotes.memos`).
    let memos: [Memo]
    /// The memo currently playing (aqua live accent on its row).
    var playingMemoId: UUID?
    /// One-line paragraph preview per memo (the pin's context), keyed by memo id.
    var pinSnippets: [UUID: String] = [:]
    var reduceTransparency: Bool = false
    var onPlay: ((Memo) -> Void)?
    var onOpenAtPin: ((Memo) -> Void)?
    var onRetry: ((Memo) -> Void)?
    var onDelete: ((Memo) -> Void)?

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Text("VOICE NOTES")
                    .font(.system(size: labelSize, weight: .medium))
                    .tracking(4)
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                    .padding(.top, 76)
                    .accessibilityAddTraits(.isHeader)
                MemoListView(
                    memos: memos,
                    playingMemoId: playingMemoId,
                    pinSnippets: pinSnippets,
                    reduceTransparency: reduceTransparency,
                    onPlay: onPlay,
                    onOpenAtPin: onOpenAtPin,
                    onRetry: onRetry,
                    onDelete: onDelete
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 150)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The rows, extracted from the ScrollView so snapshots can render them directly
/// (`ImageRenderer` doesn't rasterize ScrollView content — the V14 gotcha).
struct MemoListView: View {
    let memos: [Memo]
    var playingMemoId: UUID?
    var pinSnippets: [UUID: String] = [:]
    var reduceTransparency: Bool = false
    var onPlay: ((Memo) -> Void)?
    var onOpenAtPin: ((Memo) -> Void)?
    var onRetry: ((Memo) -> Void)?
    var onDelete: ((Memo) -> Void)?

    @ScaledMetric(relativeTo: .footnote) private var bodySize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var metaSize: CGFloat = 10

    var body: some View {
        if memos.isEmpty {
            Text("No voice notes yet — hold the mic while listening.")
                .font(.system(size: bodySize))
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 14) {
                ForEach(memos, id: \.id) { memo in
                    row(memo)
                }
            }
        }
    }

    /// One matte paper row: transcript (or its honest pending/error state), the pin
    /// line, and the actions — play/stop, open-at-pin, retry (errors only), delete.
    private func row(_ memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            transcriptText(memo)
            if let snippet = pinSnippets[memo.id], !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: metaSize, design: .serif).italic())
                    .foregroundStyle(Palette.textPrimary.opacity(0.5))
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                Text("¶\(memo.paragraphIndex + 1) · \(Transport.timeString(ms: memo.positionMs))")
                    .font(.system(size: metaSize, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                Spacer()
                if memo.status == .error {
                    action("arrow.clockwise", label: "Retry transcription") { onRetry?(memo) }
                }
                action(
                    playingMemoId == memo.id ? "stop.fill" : "play.fill",
                    label: playingMemoId == memo.id ? "Stop voice note" : "Play voice note",
                    accent: playingMemoId == memo.id
                ) { onPlay?(memo) }
                action("text.line.first.and.arrowtriangle.forward", label: "Open at pinned paragraph") {
                    onOpenAtPin?(memo)
                }
                action("trash", label: "Delete voice note") { onDelete?(memo) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            playingMemoId == memo.id
                                ? Palette.aqua.opacity(0.6)
                                : Palette.textPrimary.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    /// Honest transcript states (the chapter-status pattern): text when ready,
    /// transcribing while pending, a plain failure line when error.
    @ViewBuilder
    private func transcriptText(_ memo: Memo) -> some View {
        switch memo.status {
        case .ready:
            Text(memo.transcript?.isEmpty == false ? memo.transcript! : "(no speech detected)")
                .font(.system(size: bodySize, design: .serif))
                .foregroundStyle(Palette.textPrimary)
        case .pending:
            Text("Transcribing…")
                .font(.system(size: bodySize).italic())
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
        case .error:
            Text("Transcription failed")
                .font(.system(size: bodySize).italic())
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
        }
    }

    private func action(
        _ symbol: String, label: String, accent: Bool = false, perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent ? Palette.ink0 : Palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(
                        accent ? Palette.aqua.opacity(0.92) : Palette.textPrimary.opacity(0.08)
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview("Notes — dark") {
    let ready = Memo(paragraphIndex: 3, positionMs: 43_000, audioPath: "m1.m4a")
    ready.status = .ready
    ready.transcript = "This connects to the earlier argument about accident in design."
    let pending = Memo(paragraphIndex: 7, positionMs: 121_000, audioPath: "m2.m4a")
    let failed = Memo(paragraphIndex: 9, positionMs: 180_000, audioPath: "m3.m4a")
    failed.status = .error
    return MemoNotesView(memos: [ready, pending, failed], playingMemoId: ready.id)
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
}
