import SwiftUI

/// The narrator-voice picker — a glass-backed list plane that rises within the library surface
/// (the sanctioned morphed-list state, apple/CLAUDE.md §UI map), never a sheet. Mirrors
/// `ChapterListView`'s chrome. Selecting a row sets the book's voice and dismisses; a ▶ button
/// previews the bundled clip. A warning makes the re-download cost of switching explicit.
struct VoicePickerView: View {
    let currentVoiceId: String
    var reduceTransparency: Bool = false
    var onPreview: (NarratorVoice) -> Void = { _ in }
    var onSelect: (NarratorVoice) -> Void = { _ in }
    var onClose: () -> Void = {}

    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.top, 22).padding(.bottom, 10)
            warning.padding(.horizontal, 24).padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(VoiceCatalog.all) { voice in
                        row(voice)
                        if voice.id != VoiceCatalog.all.last?.id {
                            Divider().overlay(Palette.textPrimary.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 18)
            }
        }
        .frame(maxWidth: 420).frame(maxHeight: 520)
        .background {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            if reduceTransparency { shape.fill(Palette.surface) }
            else { Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.18)), in: shape) }
        }
        .padding(.horizontal, 24)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("NARRATOR")
                .font(.system(size: labelSize, weight: .medium)).tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            Text("Choose a voice")
                .font(.system(size: titleSize, weight: .regular, design: .serif)).tracking(1)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7)).frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(Palette.textPrimary.opacity(0.06)))
            .padding(.trailing, 14)
            .accessibilityLabel("Close voice picker")
        }
    }

    private var warning: some View {
        Text("Changing the voice re-downloads each chapter in the new voice before it plays.")
            .font(.caption2)
            .foregroundStyle(Palette.textPrimary.opacity(0.6))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func row(_ voice: NarratorVoice) -> some View {
        HStack(spacing: 14) {
            Image(systemName: voice.id == currentVoiceId ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19))
                .foregroundStyle(voice.id == currentVoiceId ? Palette.aqua.opacity(0.9) : Palette.textPrimary.opacity(0.3))
            Text(voice.id)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            if voice.isPremium {
                Text("PREMIUM")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Palette.butter)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Palette.butter.opacity(0.16)))
            }
            Spacer(minLength: 12)
            if !voice.isPremium {
                Button { onPreview(voice) } label: {
                    Image(systemName: "play.circle").font(.system(size: 19)).foregroundStyle(Palette.sky)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(voice.id)")
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(voice) }
        // `.ignore` (not `.combine`): combining + an explicit label erased the preview button's
        // own label, leaving VoiceOver no way to preview. Expose both as named actions instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(voice.id)\(voice.id == currentVoiceId ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect(voice) }
        .accessibilityAction(named: "Preview") { onPreview(voice) }
    }
}
