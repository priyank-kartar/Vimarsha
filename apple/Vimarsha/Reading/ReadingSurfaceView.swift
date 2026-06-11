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
    /// Hold-to-record voice memos (V28). Nil (previews/snapshots/no recorder) hides
    /// the mic control.
    var memoCapture: MemoCapture?
    /// The chapter's voice notes (V30). Nil (previews/snapshots) hides the Notes state.
    var memoNotes: MemoNotes?
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

    /// The Figures gallery — a morphed grid state of this same surface (V20), never
    /// a sheet. Narration keeps playing underneath.
    @State private var showGallery = false

    /// The Notes state — the chapter's voice memos as a morphed list state (V30),
    /// never a sheet. Mutually exclusive with the gallery; leaving it stops any
    /// playing memo clip.
    @State private var showNotes = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let player, let bundle = player.bundle {
                    if showNotes, let memoNotes {
                        // The morphed list state (V30): the paper body reflows into
                        // the chapter's voice notes on the same canvas.
                        MemoNotesView(
                            memos: memoNotes.memos,
                            playingMemoId: memoNotes.playingMemoId,
                            pinSnippets: pinSnippets(for: memoNotes.memos, bundle: bundle),
                            reduceTransparency: reduceTransparency,
                            onPlay: { memoNotes.play($0) },
                            onOpenAtPin: { memo in
                                memoNotes.openAtPin(memo)
                                showNotes = false
                            },
                            onRetry: { memoNotes.retry($0) },
                            onDelete: { memoNotes.delete($0) }
                        )
                        .transition(galleryTransition)
                    } else if showGallery {
                        // The morphed grid state: the paper body reflows into the
                        // figure grid on the same canvas; narration keeps playing.
                        FiguresGalleryView(
                            figures: player.allFigures,
                            images: player.blockImages,
                            onSelect: { figure in
                                player.seekToBlock(figure.startPara)
                                showGallery = false
                            }
                        )
                        .transition(galleryTransition)
                    } else {
                        chapterBody(bundle: bundle, player: player, in: geo.size)
                            .transition(galleryTransition)
                    }
                } else {
                    shell(in: geo.size)
                }
                closeBar(player: player)
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }
            .animation(
                reduceMotion ? .easeInOut(duration: 0.15)
                    : .spring(response: 0.4, dampingFraction: 0.9),
                value: showGallery
            )
            .animation(
                reduceMotion ? .easeInOut(duration: 0.15)
                    : .spring(response: 0.4, dampingFraction: 0.9),
                value: showNotes
            )
            // Leaving the Notes state (any route) stops a playing memo clip.
            .onChange(of: showNotes) { _, showing in
                if !showing { memoNotes?.stopPlayback() }
            }
            // The compact glass transport (V19) floats over the paper body — never a
            // chrome bar — and the figure carrier (V20) auto-pops above it at each
            // figure's startMs, recedes at endMs. Only when a chapter is actually loaded.
            .overlay(alignment: .bottom) {
                if let player, player.bundle != nil {
                    VStack(spacing: 14) {
                        figureCarrier(player: player)
                        memoStatusChip
                        HStack(spacing: 10) {
                            // While a memo records, narration is paused and the transport
                            // is moot — the aqua waveform puck takes its slot (a discrete
                            // state morph; the phase spring below carries it, RM dissolves).
                            // The mic control itself stays in the hierarchy throughout:
                            // removing it mid-hold would cancel the hold gesture.
                            if memoCapture?.phase == .recording {
                                MemoPuckView(
                                    level: memoCapture?.level ?? 0,
                                    elapsedMs: memoCapture?.elapsedMs ?? 0,
                                    reduceTransparency: reduceTransparency
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                            } else {
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
                                .transition(.opacity)
                            }
                            if let memoCapture {
                                MemoRecordControl(
                                    isRecording: memoCapture.phase == .recording,
                                    reduceTransparency: reduceTransparency,
                                    onHoldChanged: { holding in
                                        if holding {
                                            Task { await memoCapture.beginHold() }
                                        } else {
                                            memoCapture.endHold()
                                        }
                                    }
                                )
                            }
                        }
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
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.15)
                            : .spring(response: 0.4, dampingFraction: 0.85),
                        value: memoCapture?.phase
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
        // The gallery already shows every figure — don't double up the carrier there.
        let figures = showGallery ? [] : player.activeFigures
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

    /// One-line paragraph previews for the Notes rows (the pin's context) — derived
    /// from the bundle, the source of truth for chapter content.
    private func pinSnippets(
        for memos: [Memo], bundle: ChapterBundleDTO
    ) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: memos.compactMap { memo -> (UUID, String)? in
            guard memo.paragraphIndex >= 0, memo.paragraphIndex < bundle.blocks.count,
                  let text = bundle.blocks[memo.paragraphIndex].text
            else { return nil }
            return (memo.id, String(text.prefix(90)))
        })
    }

    /// Honest memo states above the transport (V28): the saved confirmation and the
    /// mic-permission guidance — chips on the surface, never alerts.
    @ViewBuilder
    private var memoStatusChip: some View {
        switch memoCapture?.phase {
        case .saved:
            chip(text: "Voice note saved · transcribing…", icon: "checkmark")
        case .denied:
            chip(text: "Microphone access needed — enable it in Settings", icon: "mic.slash")
        default:
            EmptyView()
        }
    }

    private func chip(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(Palette.textPrimary.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.surface))
        .transition(.opacity)
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

    /// Close = back-morph (chevron pointing back down into the stack); the Figures
    /// toggle rides the opposite corner when the chapter has figures. Controls, so
    /// glass; matte fallback under Reduce Transparency.
    private func closeBar(player: PlayerController?) -> some View {
        HStack {
            glassControl(symbol: "chevron.down", label: "Close book", action: onClose)
            Spacer()
            if memoNotes != nil, player?.bundle != nil {
                glassControl(
                    symbol: showNotes ? "text.justify.left" : "note.text",
                    label: showNotes ? "Back to reading" : "Voice notes"
                ) {
                    showGallery = false
                    showNotes.toggle()
                }
            }
            if let player, !player.allFigures.isEmpty {
                glassControl(
                    symbol: showGallery ? "text.justify.left" : "photo.on.rectangle.angled",
                    label: showGallery ? "Back to reading" : "Figures"
                ) {
                    showNotes = false
                    showGallery.toggle()
                }
            }
        }
    }

    private func glassControl(
        symbol: String, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
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
        .accessibilityLabel(label)
    }

    private var galleryTransition: AnyTransition {
        reduceMotion ? .opacity
            : .opacity.combined(with: .scale(scale: 0.97))
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
