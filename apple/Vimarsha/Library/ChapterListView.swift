import SwiftUI

/// The focused book's chapter list (V14) — a glass-backed list plane that rises *within*
/// the library surface (the sanctioned "morphed list state", apple/CLAUDE.md §UI map),
/// never a sheet or push. The plane is glass (controls/overlay material); the chapter
/// titles riding on it are matte text (content is paper).
///
/// Each row surfaces the chapter's narration lifecycle honestly (none → pending → ready /
/// error, app-architecture.md §Error posture): tap to narrate+download, a live progress
/// spinner while the backend synthesizes (minutes on a dev backend — the status *is* the
/// story), retry on error. A ready row opens the reading surface (V17 cover morph).
struct ChapterListView: View {
    let book: Book
    var reduceTransparency: Bool = false
    var onDownload: (Chapter) -> Void = { _ in }
    var onOpen: (Chapter) -> Void = { _ in }
    var onRerender: (Chapter) -> Void = { _ in }
    var onClose: () -> Void = {}
    /// Whole-book download (V-bg): start / cancel the serial download of every chapter, and
    /// the live in-flight flag (the store's `downloadingBooks`).
    var onDownloadBook: () -> Void = {}
    var onCancelBookDownload: () -> Void = {}
    var isDownloadingBook: Bool = false

    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    private var chapters: [Chapter] {
        book.chapters.sorted { $0.index < $1.index }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 22)
                .padding(.bottom, 14)
            downloadBar
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            ScrollView {
                ChapterRowsView(
                    chapters: chapters,
                    currentVoiceId: book.voiceId,
                    onDownload: onDownload,
                    onOpen: onOpen,
                    onRerender: onRerender
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxHeight: 520)
        .background {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            if reduceTransparency {
                // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte.
                shape.fill(Palette.surface)
            } else {
                Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.18)), in: shape)
            }
        }
        .padding(.horizontal, 24)
    }

    /// Count of chapters already narrated/cached — the download bar's progress numerator.
    private var readyCount: Int { chapters.filter { $0.status == .ready }.count }

    /// Whole-book download affordance: start it, watch "Downloading n/total" with a cancel,
    /// or show "Downloaded" once every chapter is cached. Glass pill (a control), matte text.
    @ViewBuilder private var downloadBar: some View {
        let total = chapters.count
        let ready = readyCount
        let allReady = total > 0 && ready == total
        Button {
            isDownloadingBook ? onCancelBookDownload() : onDownloadBook()
        } label: {
            HStack(spacing: 8) {
                if isDownloadingBook {
                    ProgressView().controlSize(.small)
                    Text("Downloading \(ready)/\(total) · tap to stop")
                } else if allReady {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Downloaded")
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text(ready > 0 ? "Download book · \(ready)/\(total)" : "Download book")
                }
            }
            .font(.system(size: labelSize + 3, weight: .semibold))
            .foregroundStyle(Palette.textPrimary.opacity(allReady && !isDownloadingBook ? 0.55 : 0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .background {
            let shape = Capsule()
            if reduceTransparency {
                shape.fill(Palette.surface)
            } else {
                Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.22)).interactive(), in: shape)
            }
        }
        .disabled(allReady && !isDownloadingBook)
        .accessibilityLabel(isDownloadingBook ? "Stop downloading the book" : "Download the whole book")
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("CHAPTERS")
                .font(.system(size: labelSize, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            Text(book.title)
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(1)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 56)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .background(Circle().fill(Palette.textPrimary.opacity(0.06)))
            .padding(.trailing, 14)
            .accessibilityLabel("Close chapters")
        }
    }
}

/// The rows column, extracted from the ScrollView so snapshot tests can render it
/// directly (`ImageRenderer` doesn't rasterize ScrollView content).
struct ChapterRowsView: View {
    let chapters: [Chapter]
    let currentVoiceId: String
    var onDownload: (Chapter) -> Void = { _ in }
    var onOpen: (Chapter) -> Void = { _ in }
    var onRerender: (Chapter) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(chapters) { chapter in
                ChapterRow(
                    chapter: chapter,
                    currentVoiceId: currentVoiceId,
                    onDownload: onDownload,
                    onOpen: onOpen,
                    onRerender: onRerender
                )
                if chapter.id != chapters.last?.id {
                    Divider().overlay(Palette.textPrimary.opacity(0.08))
                }
            }
        }
    }
}

/// One chapter row: matte title + the lifecycle affordance. The whole row is tappable
/// when actionable (download/retry) — never a bare 28pt icon target.
private struct ChapterRow: View {
    let chapter: Chapter
    let currentVoiceId: String
    var onDownload: (Chapter) -> Void
    var onOpen: (Chapter) -> Void
    var onRerender: (Chapter) -> Void

    @ScaledMetric(relativeTo: .caption2) private var indexSize: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var rowTitleSize: CGFloat = 15

    private var isStale: Bool {
        ChapterStaleness.isStale(
            status: chapter.status,
            narratedVoiceId: chapter.narratedVoiceId,
            bookVoiceId: currentVoiceId
        )
    }

    var body: some View {
        // Only actionable rows are buttons — a disabled Button would dim the title, and a
        // pending chapter must not read as broken (the spinner is the story). A ready row
        // opens the reading surface (V17); none/error rows narrate/retry.
        Group {
            switch chapter.status {
            case .none, .error:
                Button { onDownload(chapter) } label: { rowContent }
                    .buttonStyle(.plain)
            case .ready:
                Button {
                    switch ChapterOpenRouting.action(status: .ready, isStale: isStale) {
                    case .rerender: onRerender(chapter)
                    case .open: onOpen(chapter)
                    case .download: onDownload(chapter)
                    }
                } label: { rowContent }
                .buttonStyle(.plain)
            case .pending:
                rowContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onLongPressGesture(minimumDuration: 0.5) { onRerender(chapter) }
        // VoiceOver equivalent of the hold gesture (apple/CLAUDE.md §Accessibility: every
        // gesture-only interaction needs an accessibility action).
        .accessibilityAction(named: "Re-narrate chapter") { onRerender(chapter) }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", chapter.index + 1))
                .font(.system(size: indexSize, weight: .medium).monospacedDigit())
                .tracking(1)
                .foregroundStyle(Palette.textPrimary.opacity(0.45))
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.system(size: rowTitleSize, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                if chapter.status == .error, let reason = chapter.errorReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(Palette.textPrimary.opacity(0.55))
                }
                if isStale {
                    Text("Will re-narrate in \(currentVoiceId)")
                        .font(.caption2)
                        .foregroundStyle(Palette.sky.opacity(0.85))
                }
            }
            Spacer(minLength: 12)
            statusGlyph
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    /// The lifecycle, visually: download arrow (sky, interactive) → spinner (aqua, live) →
    /// filled check (aqua — narrated and cached) / retry arrow (error).
    @ViewBuilder
    private var statusGlyph: some View {
        switch chapter.status {
        case .none:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Palette.sky)
        case .pending:
            ProgressView()
                .controlSize(.small)
                .tint(Palette.aqua)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Palette.aqua.opacity(0.9))
        case .error:
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Palette.sky)
        }
    }

    private var accessibilityText: String {
        let state = switch chapter.status {
        case .none: "not downloaded, double-tap to narrate"
        case .pending: "narrating"
        case .ready: "ready, double-tap to read"
        case .error: "failed, double-tap to retry"
        }
        return "Chapter \(chapter.index + 1), \(chapter.title), \(state)"
    }
}
