import Foundation
#if arch(arm64)
import MediaRemoteAdapter
#endif

/// Service that wraps MediaRemoteAdapter's MediaController to provide
/// controlled muting during transcription.
///
/// Instead of pausing playback, this service mutes the system output volume
/// while transcription is active (only if media is actually playing) and
/// restores the previous volume afterwards. This keeps media playing in the
/// background so it picks up exactly where it was, just silenced.
///
/// It only mutes if media is currently playing, and only restores the volume
/// if we were the ones who muted it.
@MainActor
final class MediaPlaybackService {
    static let shared = MediaPlaybackService()

    #if arch(arm64)
    private let mediaController = MediaController()

    /// What we changed to mute the output device, used to restore it exactly later.
    private var outputMuteToken: AudioDevice.OutputMuteToken?
    #endif

    private init() {}

    // MARK: - Public API

    #if arch(arm64)
    /// Mutes the default output device if media is currently playing.
    ///
    /// What was changed is stored so it can be restored via ``unmuteIfWeMuted(_:)``.
    ///
    /// - Returns: `true` if we muted the output, `false` if nothing was playing,
    ///   the playback state couldn't be determined, or the device couldn't be muted.
    func muteIfMediaPlaying() async -> Bool {
        let isPlaying = await self.isMediaPlaying()

        guard isPlaying else {
            DebugLogger.shared.debug(
                "MediaPlaybackService: Media is not playing, nothing to mute",
                source: "MediaPlaybackService"
            )
            return false
        }

        // Mute the default output device using whatever method it supports (mute property,
        // master volume, or per-channel). Bluetooth / HDMI devices often don't expose a
        // settable master volume scalar, so a plain volume-to-zero isn't enough on its own.
        guard let token = AudioDevice.muteDefaultOutput() else {
            DebugLogger.shared.warning(
                "MediaPlaybackService: Could not mute the output device, skipping mute",
                source: "MediaPlaybackService"
            )
            return false
        }

        self.outputMuteToken = token
        DebugLogger.shared.info(
            "MediaPlaybackService: Media is playing, muted output via \(token.methodDescription)",
            source: "MediaPlaybackService"
        )
        return true
    }

    /// Restores the output device we muted, but only if we were the ones who muted it.
    ///
    /// - Parameter weMuted: `true` if ``muteIfMediaPlaying()`` returned `true` for this session.
    func unmuteIfWeMuted(_ weMuted: Bool) async {
        guard weMuted else {
            DebugLogger.shared.debug(
                "MediaPlaybackService: We didn't mute, not restoring volume",
                source: "MediaPlaybackService"
            )
            return
        }

        guard let token = self.outputMuteToken else {
            DebugLogger.shared.debug(
                "MediaPlaybackService: No stored mute state to restore",
                source: "MediaPlaybackService"
            )
            return
        }

        AudioDevice.restoreOutput(token)
        self.outputMuteToken = nil
        DebugLogger.shared.info(
            "MediaPlaybackService: Restored output (\(token.methodDescription))",
            source: "MediaPlaybackService"
        )
    }

    /// Pauses system media playback if media is currently playing.
    ///
    /// - Returns: `true` if we sent a pause command, `false` if nothing was playing
    ///   or the playback state couldn't be determined.
    func pauseIfPlaying() async -> Bool {
        let isPlaying = await self.isMediaPlaying()

        guard isPlaying else {
            DebugLogger.shared.debug(
                "MediaPlaybackService: Media is not playing, nothing to pause",
                source: "MediaPlaybackService"
            )
            return false
        }

        self.mediaController.pause()
        DebugLogger.shared.info(
            "MediaPlaybackService: Media is playing, sent pause command",
            source: "MediaPlaybackService"
        )
        return true
    }

    /// Resumes media playback, but only if we were the ones who paused it.
    ///
    /// - Parameter wePaused: `true` if ``pauseIfPlaying()`` returned `true` for this session.
    func resumeIfWePaused(_ wePaused: Bool) async {
        guard wePaused else {
            DebugLogger.shared.debug(
                "MediaPlaybackService: We didn't pause media, not resuming",
                source: "MediaPlaybackService"
            )
            return
        }

        // Use an explicit play() command — never toggle.
        self.mediaController.play()
        DebugLogger.shared.info(
            "MediaPlaybackService: Resumed media playback (we paused it)",
            source: "MediaPlaybackService"
        )
    }

    // MARK: - Private

    /// Determines whether system media is currently playing.
    ///
    /// - Note: Uses a local one-shot gate to protect against `MediaRemoteAdapter`
    ///   firing the `getTrackInfo` callback more than once, which would otherwise
    ///   crash with `EXC_BREAKPOINT` (SIGTRAP) due to double-resume of a
    ///   `CheckedContinuation`.
    private func isMediaPlaying() async -> Bool {
        return await withCheckedContinuation { continuation in
            let resumeLock = NSLock()
            var didResume = false

            func resumeOnce(_ value: Bool) {
                var shouldResume = false

                resumeLock.lock()
                if !didResume {
                    didResume = true
                    shouldResume = true
                }
                resumeLock.unlock()

                guard shouldResume else {
                    DebugLogger.shared.warning(
                        "MediaPlaybackService: Suppressed duplicate callback (MediaRemoteAdapter callback fired more than once)",
                        source: "MediaPlaybackService"
                    )
                    return
                }

                continuation.resume(returning: value)
            }

            self.mediaController.getTrackInfo { trackInfo in
                // If no track info is available, nothing is playing
                guard let trackInfo = trackInfo else {
                    DebugLogger.shared.debug(
                        "MediaPlaybackService: No track info available, nothing is playing",
                        source: "MediaPlaybackService"
                    )
                    resumeOnce(false)
                    return
                }

                // Determine if media is currently playing
                // Use isPlaying if available, otherwise check playbackRate
                let isPlaying: Bool
                if let playing = trackInfo.payload.isPlaying {
                    isPlaying = playing
                } else {
                    // playbackRate of 1.0 typically means playing, 0.0 means paused
                    isPlaying = (trackInfo.payload.playbackRate ?? 0.0) > 0.0
                }

                DebugLogger.shared.debug(
                    """
                    MediaPlaybackService: Track info received
                    - App: \(trackInfo.payload.applicationName ?? "Unknown")
                    - Bundle: \(trackInfo.payload.bundleIdentifier ?? "Unknown")
                    - Title: \(trackInfo.payload.title ?? "Unknown")
                    - isPlaying: \(trackInfo.payload.isPlaying?.description ?? "nil")
                    - playbackRate: \(trackInfo.payload.playbackRate?.description ?? "nil")
                    - Determined playing: \(isPlaying)
                    """,
                    source: "MediaPlaybackService"
                )

                resumeOnce(isPlaying)
            }
        }
    }
    #else
    // Intel Mac stub - media control not available
    func muteIfMediaPlaying() async -> Bool {
        DebugLogger.shared.debug(
            "MediaPlaybackService: Not available on Intel Macs",
            source: "MediaPlaybackService"
        )
        return false
    }

    func unmuteIfWeMuted(_ weMuted: Bool) async {
        // No-op on Intel
    }

    func pauseIfPlaying() async -> Bool {
        DebugLogger.shared.debug(
            "MediaPlaybackService: Not available on Intel Macs",
            source: "MediaPlaybackService"
        )
        return false
    }

    func resumeIfWePaused(_ wePaused: Bool) async {
        // No-op on Intel
    }
    #endif
}
