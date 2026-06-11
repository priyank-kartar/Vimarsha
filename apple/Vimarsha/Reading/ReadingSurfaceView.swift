import SwiftUI

/// The narrated reading surface (V17; apple/CLAUDE.md §UI map state 3) — the state the
/// focused hardback morphs OPEN into. The cover art is the shared element (matched
/// geometry from the tower card to the small cover plate up top); closing back-morphs,
/// never a dismiss-pop (Prime Directive: states of one surface, no pages).
///
/// V17 shipped the morph + the canvas shell; V18 fills the body: the cached bundle's
/// blocks as matte serif paper (`ReadingBlocksView`), the narrated paragraph highlighted
/// and auto-scrolled on `paraTimings` (via the player's `TimingIndex`). The glass
/// transport cluster lands in V19.
struct ReadingSurfaceView: View {
    /// The opened book as the shelf renders it (real art or generated cloth).
    let book: ShelfBook
    let chapterIndex: Int
    let chapterTitle: String
    /// The chapter's player (owns the bundle + playhead). Nil (previews/snapshots/no
    /// engine) renders the V17 shell.
    var player: PlayerController?
    var reduceTransparency: Bool = false
    var onClose: () -> Void = {}
    /// The cover-morph namespace; nil (snapshots/Reduce Motion) renders without the
    /// shared element.
    var morphNamespace: Namespace.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 30

    /// Auto-scroll guards (Flutter `ReadingView` parity): don't re-scroll to the block
    /// we already centered, and don't yank the view back while the user reads ahead.
    @State private var lastScrolledTo: String?
    @State private var lastUserScroll: Date = .distantPast
    private static let userScrollCooldown: TimeInterval = 4

    /// The figure carrier's paging memory (V20). The rendered selection is *derived*
    /// (`FigureOverlaySelection.reconciled`) every frame — this only remembers which
    /// stacked card the user paged to while the active set stays stable.
    @State private var figurePaging: FigureOverlaySelection?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let player, let bundle = player.bundle {
                    chapterBody(bundle: bundle, player: player, in: geo.size)
                } else {
                    shell(in: geo.size)
                }
                closeBar
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }
            // The compact glass transport (V19) floats over the paper body — never a
            // chrome bar — and the figure carrier (V20) auto-pops above it at each
            // figure's startMs, recedes at endMs. Only when a chapter is actually loaded.
            .overlay(alignment: .bottom) {
                if let player, player.bundle != nil {
                    VStack(spacing: 14) {
                        figureCarrier(player: player)
                        TransportClusterView(
                            positionMs: player.positionMs,
                            durationMs: player.durationMs,
                            isPlaying: player.isPlaying,
                            rate: player.rate,
                            reduceTransparency: reduceTransparency,
                            onPlayPause: { player.togglePlayPause() },
                            onSkip: { player.skip(byMs: $0) },
                            onCycleRate: { player.setRate(Transport.nextRate(after: player.rate)) }
                        )
                    }
                    .frame(maxWidth: 380)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                    // Pop/recede is a discrete state morph: interruptible spring keyed
                    // on the active set; Reduce Motion cross-dissolves instead.
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.15)
                            : .spring(response: 0.45, dampingFraction: 0.85),
                        value: FigureOverlaySelection.key(for: player.activeFigures)
                    )
                }
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
    }

    /// The narrated reading body: cover plate + masthead scroll away with the text (the
    /// chapter opens with its cover, then reads); the live paragraph carries the wash and
    /// the view follows the narration.
    private func chapterBody(
        bundle: ChapterBundleDTO, player: PlayerController, in size: CGSize
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    coverPlate(in: size)
                        .padding(.top, 66)
                    masthead
                        .padding(.top, 24)
                        .padding(.bottom, 36)
                    ReadingBlocksView(
                        blocks: bundle.blocks,
                        activeBlockId: player.currentBlockId,
                        images: player.blockImages,
                        onTapBlock: { id in player.seekToBlock(id) }
                    )
                    .padding(.horizontal, 22)
                    // Keep the last lines clear of the transport cluster.
                    .padding(.bottom, 150)
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .onScrollPhaseChange { _, newPhase in
                // A finger on the scroll = the user is reading ahead; back off.
                if newPhase == .interacting { lastUserScroll = .now }
            }
            .onChange(of: player.currentBlockId) { _, id in
                autoScroll(to: id, proxy: proxy)
            }
            .onAppear {
                // Land on the resume position without animating through the chapter.
                if let id = player.currentBlockId {
                    lastScrolledTo = id
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.3))
                }
            }
        }
    }

    /// Follow the narration: settle the live block ~30% down the viewport. Skips while
    /// the user recently scrolled (cooldown) or when already there; Reduce Motion jumps
    /// (position is information — only the glide is decoration).
    private func autoScroll(to id: String?, proxy: ScrollViewProxy) {
        guard let id, id != lastScrolledTo,
              Date.now.timeIntervalSince(lastUserScroll) > Self.userScrollCooldown
        else { return }
        lastScrolledTo = id
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.3))
        }
    }

    /// The glass figure carrier (V20): present exactly while figures are active at the
    /// playhead — auto-pop at `startMs`, recede at `endMs` (TimingIndex owns the spans).
    @ViewBuilder
    private func figureCarrier(player: PlayerController) -> some View {
        let figures = player.activeFigures
        if let selection = FigureOverlaySelection.reconciled(figurePaging, with: figures) {
            FigureCarrierView(
                figures: figures,
                selectedIndex: selection.index,
                images: player.blockImages,
                reduceTransparency: reduceTransparency,
                onPrevious: { figurePaging = selection.previous(count: figures.count) },
                onNext: { figurePaging = selection.next(count: figures.count) }
            )
            .transition(
                reduceMotion ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
                        .combined(with: .scale(scale: 0.92, anchor: .bottom))
            )
        }
    }

    /// The V17 shell (no player/bundle — previews, snapshots, forced captures).
    private func shell(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 54)
            coverPlate(in: size)
                .padding(.top, 6)
            masthead
                .padding(.top, 26)
            Spacer(minLength: 0)
            readyMark
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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
