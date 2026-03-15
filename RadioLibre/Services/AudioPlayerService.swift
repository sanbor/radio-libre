import AVFoundation
import Foundation

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    // MARK: - Published State

    @Published private(set) var state: PlaybackState = .idle
    @Published var volume: Float = 1.0 {
        didSet { player.volume = volume }
    }

    enum PlaybackState: Equatable {
        case idle
        case loading(station: StationDTO)
        case playing(station: StationDTO)
        case paused(station: StationDTO)
        case error(station: StationDTO, message: String)

        static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.loading(let a), .loading(let b)):
                return a == b
            case (.playing(let a), .playing(let b)):
                return a == b
            case (.paused(let a), .paused(let b)):
                return a == b
            case (.error(let aStation, let aMsg), .error(let bStation, let bMsg)):
                return aStation == bStation && aMsg == bMsg
            default:
                return false
            }
        }
    }

    // MARK: - Computed Properties

    var currentStation: StationDTO? {
        switch state {
        case .idle: return nil
        case .loading(let station): return station
        case .playing(let station): return station
        case .paused(let station): return station
        case .error(let station, _): return station
        }
    }

    var isPlaying: Bool {
        if case .playing = state { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    @Published private(set) var isBuffering: Bool = false

    // MARK: - Private

    private static let initialBufferDuration: TimeInterval = 3.0
    private static let stallBufferIncrement: TimeInterval = 3.0
    private static let maxBufferDuration: TimeInterval = 15.0

    let player: AVPlayer
    private var playerItemObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var bufferKeepUpObservation: NSKeyValueObservation?
    private let service: RadioBrowserService
    private let nowPlayingService: NowPlayingService
    private let liveActivityService: LiveActivityService
    private var currentBufferDuration: TimeInterval = initialBufferDuration
    private var stallCount: Int = 0

    // MARK: - Init

    init(
        player: AVPlayer = AVPlayer(),
        service: RadioBrowserService = .shared,
        nowPlayingService: NowPlayingService? = nil,
        liveActivityService: LiveActivityService? = nil
    ) {
        self.player = player
        self.service = service
        self.nowPlayingService = nowPlayingService ?? NowPlayingService.shared
        self.liveActivityService = liveActivityService ?? LiveActivityService.shared
        player.volume = volume
        setupAudioSession()
        setupInterruptionObserver()
        setupRouteChangeObserver()
        observeTimeControlStatus()
    }

    // MARK: - Public API

    func play(station: StationDTO) {
        guard let streamURL = station.streamURL else {
            state = .error(station: station, message: AppError.streamURLInvalid.errorDescription ?? "Invalid stream URL")
            return
        }

        // Reset buffer config when switching to a different station
        if currentStation?.stationuuid != station.stationuuid {
            currentBufferDuration = Self.initialBufferDuration
            stallCount = 0
        }

        state = .loading(station: station)
        liveActivityService.startOrUpdate(station: station, isPlaying: false, isLoading: true, isBuffering: false)

        // Cancel any existing observations for the old item
        playerItemObservation?.invalidate()
        playerItemObservation = nil
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        bufferKeepUpObservation?.invalidate()
        bufferKeepUpObservation = nil

        let asset = AVURLAsset(url: streamURL)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = currentBufferDuration

        player.automaticallyWaitsToMinimizeStalling = true

        observePlayerItemStatus(item: item, station: station)
        observeBufferState(item: item, station: station)

        player.replaceCurrentItem(with: item)
        player.play()

        nowPlayingService.updateNowPlaying(station: station, isPlaying: true)

        // Fire-and-forget click tracking
        Task {
            await service.trackClick(stationuuid: station.stationuuid)
        }
    }

    func pause() {
        guard let station = currentStation else { return }
        player.pause()
        state = .paused(station: station)
        nowPlayingService.updateNowPlaying(station: station, isPlaying: false)
        liveActivityService.startOrUpdate(station: station, isPlaying: false, isLoading: false, isBuffering: false)
    }

    func resume() {
        guard let station = currentStation else { return }
        // For live radio, resume = reconnect to stream
        play(station: station)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerItemObservation?.invalidate()
        playerItemObservation = nil
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        bufferKeepUpObservation?.invalidate()
        bufferKeepUpObservation = nil
        isBuffering = false
        stallCount = 0
        currentBufferDuration = Self.initialBufferDuration
        state = .idle
        nowPlayingService.clearNowPlaying()
        liveActivityService.end()
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused:
            resume()
        case .error:
            resume()
        default:
            break
        }
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            // Audio session errors will surface when playback is attempted
        }
    }

    // MARK: - Interruption Handling

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Route Change Handling

    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    // MARK: - KVO Observations

    private func observeTimeControlStatus() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, let station = self.currentStation else { return }
                switch player.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    self.state = .loading(station: station)
                    self.liveActivityService.startOrUpdate(station: station, isPlaying: false, isLoading: true, isBuffering: self.isBuffering)
                case .playing:
                    self.state = .playing(station: station)
                    self.nowPlayingService.updateNowPlaying(station: station, isPlaying: true)
                    self.liveActivityService.startOrUpdate(station: station, isPlaying: true, isLoading: false, isBuffering: false)
                case .paused:
                    // Only update if we're not already in idle or error state
                    if case .loading = self.state {
                        // Still loading, player briefly pauses — ignore
                    } else if case .error = self.state {
                        // Already errored — ignore
                    } else if case .idle = self.state {
                        // Already stopped — ignore
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    private func observeBufferState(item: AVPlayerItem, station: StationDTO) {
        bufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, item.isPlaybackBufferEmpty else { return }
                self.isBuffering = true
                self.stallCount += 1
                let newDuration = Self.initialBufferDuration + Self.stallBufferIncrement * TimeInterval(self.stallCount)
                self.currentBufferDuration = min(newDuration, Self.maxBufferDuration)
                item.preferredForwardBufferDuration = self.currentBufferDuration
            }
        }

        bufferKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, item.isPlaybackLikelyToKeepUp else { return }
                self.isBuffering = false
            }
        }
    }

    private func observePlayerItemStatus(item: AVPlayerItem, station: StationDTO) {
        playerItemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .failed:
                    let message = item.error?.localizedDescription ?? "Playback failed"
                    self.state = .error(station: station, message: message)
                    self.nowPlayingService.updateNowPlaying(station: station, isPlaying: false)
                    self.liveActivityService.end()
                case .readyToPlay:
                    break // timeControlStatus handles the transition to playing
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
