import SwiftUI

/// The narrated reading surface (V17; apple/CLAUDE.md §UI map state 3) — the state the
/// focused hardback morphs OPEN into. The cover art is the shared element (matched
/// geometry from the tower card to the small cover plate up top); closing back-morphs,
/// never a dismiss-pop (Prime Directive: states of one surface, no pages).
///
/// V17 ships the morph + the canvas shell: cover plate, chapter masthead, and an honest
/// ready-state mark. The narrated blocks/highlight/auto-scroll fill the body in V18; the
/// glass transport cluster lands in V19.
struct ReadingSurfaceView: View {
    /// The opened book as the shelf renders it (real art or generated cloth).
    let book: ShelfBook
    let chapterIndex: Int
    let chapterTitle: String
    var reduceTransparency: Bool = false
    var onClose: () -> Void = {}
    /// The cover-morph namespace; nil (snapshots/Reduce Motion) renders without the
    /// shared element.
    var morphNamespace: Namespace.ID?

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                closeBar
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
                coverPlate(in: geo.size)
                    .padding(.top, 6)
                masthead
                    .padding(.top, 26)
                Spacer(minLength: 0)
                readyMark
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Palette.canvas.ignoresSafeArea())
    }

    // MARK: Pieces

    /// Close = back-morph (chevron pointing back down into the stack). A control, so
    /// glass; matte fallback under Reduce Transparency.
    private var closeBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .background {
                if reduceTransparency {
                    Circle().fill(Palette.surface)
                        .overlay(Circle().strokeBorder(Palette.sky.opacity(0.5), lineWidth: 1))
                } else {
                    Color.clear.glassEffect(
                        .regular.tint(Palette.sky.opacity(0.26)).interactive(), in: .circle
                    )
                }
            }
            .accessibilityLabel("Close book")
            Spacer()
        }
    }

    /// The shared element: the same hardback, settled small at the top of the canvas.
    @ViewBuilder
    private func coverPlate(in size: CGSize) -> some View {
        let width = min(size.width * 0.40, 200)
        let plate = HardbackCoverView(book: book)
            .frame(width: width)
            .shadow(color: .black.opacity(0.30), radius: 14, y: 9)
        if let morphNamespace {
            plate.matchedGeometryEffect(id: "cover-\(book.id)", in: morphNamespace)
        } else {
            plate
        }
    }

    /// Chapter masthead in the editorial serif — content is paper, matte on the canvas.
    private var masthead: some View {
        VStack(spacing: 10) {
            Text(String(format: "CHAPTER %02d", chapterIndex + 1))
                .font(.system(size: labelSize, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            Text(chapterTitle)
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(1)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 36)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Honest interim state for the V17 shell: the chapter is cached and narratable —
    /// the narrated body (V18) and transport (V19) take this spot next.
    private var readyMark: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Palette.aqua.opacity(0.85))
            Text("NARRATION READY")
                .font(.system(size: labelSize, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.45))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Narration ready")
    }
}

#Preview("Reading surface — dark") {
    ReadingSurfaceView(
        book: ShelfBook.seeds[3], chapterIndex: 0, chapterTitle: "The Shape of Accidents"
    )
    .preferredColorScheme(.dark)
}
