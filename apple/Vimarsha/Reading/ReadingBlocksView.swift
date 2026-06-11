import SwiftUI

/// The chapter body (V18): ordered typed blocks rendered as matte paper on the canvas —
/// serif body text (the bookish New York warmth, apple/CLAUDE.md §Typography), figures
/// inline as paper (matte images + captions, never glass), quotes with a slate rule.
/// The narrated block carries the highlight wash. Extracted from the surface's
/// ScrollView so snapshot tests can render it directly (`ImageRenderer` doesn't
/// rasterize ScrollView content — the V14 gotcha).
struct ReadingBlocksView: View {
    let blocks: [BlockDTO]
    /// The block being narrated (highlight + auto-scroll anchor); nil = nothing live.
    let activeBlockId: String?
    /// Cached figure images keyed by source block id (`PlayerController.blockImages`).
    var images: [String: Image] = [:]
    /// Tap-a-paragraph-to-seek (V19); nil renders an inert body (snapshots/previews).
    var onTapBlock: ((String) -> Void)?

    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .title2) private var headingSize: CGFloat = 23
    @ScaledMetric(relativeTo: .title3) private var subheadingSize: CGFloat = 19
    @ScaledMetric(relativeTo: .caption) private var captionSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks, id: \.id) { block in
                row(block)
                    .id(block.id)  // the auto-scroll target (ScrollViewReader)
            }
        }
    }

    @ViewBuilder
    private func row(_ block: BlockDTO) -> some View {
        switch block.kind {
        case "image", "figure":
            figureRow(block)
        case "heading":
            if let text = nonEmpty(block.text) {
                textRow(block) {
                    Text(text)
                        .font(.system(
                            size: (block.level ?? 1) <= 1 ? headingSize : subheadingSize,
                            weight: .regular, design: .serif
                        ))
                        .tracking(0.5)
                        .padding(.top, 14)
                }
            }
        case "blockquote", "pullquote":
            if let text = nonEmpty(block.text ?? block.caption) {
                textRow(block) {
                    Text(text)
                        .font(.system(size: bodySize, weight: .regular, design: .serif))
                        .italic()
                        .lineSpacing(5)
                        .padding(.leading, 14)
                        .overlay(alignment: .leading) {
                            // Decorative rule — slate is sanctioned for dividers/accents.
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Palette.slate.opacity(0.7))
                                .frame(width: 3)
                        }
                }
            }
        default:
            // paragraph (and any future kind that carries text — degrade, don't drop)
            if let text = nonEmpty(block.text) {
                textRow(block) {
                    Text(text)
                        .font(.system(size: bodySize, weight: .regular, design: .serif))
                        .lineSpacing(6)
                }
            }
        }
    }

    /// Shared text-row chrome: matte ink/paper type + the narration highlight wash when
    /// this block is the one being read aloud + tap-to-seek (V19; a gesture-only
    /// interaction, so VoiceOver gets an explicit action — apple/CLAUDE.md §Accessibility).
    private func textRow(_ block: BlockDTO, @ViewBuilder content: () -> some View) -> some View {
        content()
            .foregroundStyle(Palette.textPrimary.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if block.id == activeBlockId {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.narrationHighlight)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTapBlock?(block.id) }
            .accessibilityAction(named: "Read from here") { onTapBlock?(block.id) }
    }

    /// A figure as paper: the cached image matte on the canvas (subtle rounding + contact
    /// shadow — physical, not glass), caption beneath in small caps-ish quiet type.
    /// No cached image → the caption alone (best-effort parity with the downloader).
    @ViewBuilder
    private func figureRow(_ block: BlockDTO) -> some View {
        let caption = nonEmpty(block.caption ?? block.alt)
        if let image = images[block.id] {
            VStack(spacing: 8) {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                if let caption {
                    captionText(caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(caption ?? "Figure")
        } else if let caption {
            captionText(caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
    }

    private func captionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: captionSize, weight: .regular))
            .foregroundStyle(Palette.textPrimary.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
