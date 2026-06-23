import SwiftUI

/// A tapped inline figure opened full-bleed to read it up close: the matte image floats on a
/// dimmed glass scrim (content is paper; the scrim + close are glass — apple/CLAUDE.md §Liquid
/// Glass), pinch/drag to zoom, double-tap to toggle, caption beneath. A *state of the surface*
/// that fades/scales in — never a `.sheet` (Prime Directive). Tap the scrim or the close
/// control to dismiss.
struct FigureViewerView: View {
    let image: Image
    var caption: String?
    var reduceTransparency: Bool = false
    var onClose: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private var liveZoom: CGFloat { max(1, min(zoom * pinch, 6)) }

    var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 16) {
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(liveZoom)
                    .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                    .gesture(magnify)
                    .simultaneousGesture(pan)
                    .onTapGesture(count: 2) { toggleZoom() }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .accessibilityLabel(caption ?? "Figure")

                if let caption, zoom == 1 {
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textPrimary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .transition(.opacity)
                }
            }
            .padding(24)

            closeButton
        }
        .transition(reduceTransparency ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
    }

    private var scrim: some View {
        Group {
            if reduceTransparency {
                Palette.canvas.opacity(0.96)
            } else {
                Color.clear.glassEffect(.regular.tint(Palette.ink0.opacity(0.55)), in: .rect)
                    .background(Palette.ink0.opacity(0.5))
            }
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .background {
                    if reduceTransparency {
                        Circle().fill(Palette.surface)
                    } else {
                        Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.26)).interactive(), in: .circle)
                    }
                }
                .accessibilityLabel("Close figure")
            }
            Spacer()
        }
        .padding(.top, 14)
        .padding(.horizontal, 20)
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .updating($pinch) { value, state, _ in state = value }
            .onEnded { value in zoom = max(1, min(zoom * value, 6)) }
    }

    private var pan: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in if zoom > 1 { state = value.translation } }
            .onEnded { value in
                guard zoom > 1 else { return }
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if zoom > 1 {
                zoom = 1
                offset = .zero
            } else {
                zoom = 2.5
            }
        }
    }
}
