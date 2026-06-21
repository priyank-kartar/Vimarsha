import Foundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Lock-screen / Control-Center "Now Playing" + remote transport for the active chapter.
/// On iOS this is the lock-screen art + play/pause/scrub; on macOS the same surfaces via
/// media keys / Control Center. Commands route back through `PlayerController` (never the
/// engine directly) so app state stays in sync.
///
/// We only refresh on transport *changes* (play/pause/seek/rate/load): iOS advances the
/// lock-screen scrubber itself from `ElapsedPlaybackTime` + `PlaybackRate`, so a per-tick
/// update is unnecessary (and would fight the off-main playback ticker).
final class NowPlayingCenter {
    /// Wire the remote commands to the current controller. Clears any prior target first so
    /// a freshly loaded chapter owns the lock-screen controls.
    func bind(
        play: @escaping () -> Void,
        pause: @escaping () -> Void,
        toggle: @escaping () -> Void,
        skip: @escaping (Double) -> Void,
        seek: @escaping (Double) -> Void
    ) {
        let c = MPRemoteCommandCenter.shared()
        for cmd in [c.playCommand, c.pauseCommand, c.togglePlayPauseCommand,
                    c.skipForwardCommand, c.skipBackwardCommand,
                    c.changePlaybackPositionCommand] {
            cmd.removeTarget(nil)
            cmd.isEnabled = true
        }
        c.skipForwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.preferredIntervals = [15]
        c.playCommand.addTarget { _ in play(); return .success }
        c.pauseCommand.addTarget { _ in pause(); return .success }
        c.togglePlayPauseCommand.addTarget { _ in toggle(); return .success }
        c.skipForwardCommand.addTarget { ev in
            skip((ev as? MPSkipIntervalCommandEvent)?.interval ?? 15); return .success
        }
        c.skipBackwardCommand.addTarget { ev in
            skip(-((ev as? MPSkipIntervalCommandEvent)?.interval ?? 15)); return .success
        }
        c.changePlaybackPositionCommand.addTarget { ev in
            guard let e = ev as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            seek(e.positionTime); return .success
        }
    }

    func update(
        title: String, album: String, artist: String,
        durationMs: Int, positionMs: Int, rate: Double, isPlaying: Bool,
        artwork: MPMediaItemArtwork? = nil
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: Double(durationMs) / 1000,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(positionMs) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Wrap a decoded cover image as lock-screen artwork (the cover is matte paper, but the
    /// lock screen wants a bitmap). Platform-shimmed: UIImage on iOS, NSImage on macOS.
    ///
    /// MUST be `nonisolated`: MediaPlayer invokes the request handler on its OWN background
    /// queue, so the closure can't capture main-actor state (under default-main-actor isolation
    /// that traps with a dispatch-queue assertion — EXC_BREAKPOINT). We capture only the
    /// `Sendable` CGImage and build the platform image inside the handler.
    nonisolated static func artwork(from cgImage: CGImage) -> MPMediaItemArtwork {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        return MPMediaItemArtwork(boundsSize: size) { _ in
            #if canImport(UIKit)
            UIImage(cgImage: cgImage)
            #else
            NSImage(cgImage: cgImage, size: size)
            #endif
        }
    }
}
