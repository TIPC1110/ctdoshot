import Foundation
import AppKit
import Combine
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreVideo

public enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case paused
    case stopping
}

public enum RecordMode: Equatable, Sendable {
    case fullScreen(displayID: CGDirectDisplayID? = nil)
    case region(CGRect, displayID: CGDirectDisplayID? = nil)
}

public enum ExportFormat: Equatable, Sendable {
    case mp4
    case gif
}

public enum ScreenRecorderError: LocalizedError, Equatable {
    case permissionDenied
    case noDisplayFound
    case assetWriterCreationFailed
    case streamStartFailed(String)
    case alreadyRecording
    case notRecording
    case micUnavailable
    case invalidRegion
    case saveFailed
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen recording permission was denied."
        case .noDisplayFound: return "No valid display was found for recording."
        case .assetWriterCreationFailed: return "Failed to create AVAssetWriter session."
        case .streamStartFailed(let reason): return "ScreenCaptureKit stream failed to start: \(reason)"
        case .alreadyRecording: return "Recording is already in progress."
        case .notRecording: return "No active recording session to stop or pause."
        case .micUnavailable: return "Microphone device is unavailable."
        case .invalidRegion: return "Selection region is invalid."
        case .saveFailed: return "Failed to save recorded asset."
        case .cancelled: return "Recording session was cancelled."
        }
    }
}

public typealias RecordingError = ScreenRecorderError

/// Thread-safe sample buffer delegate managing SCStream video frames and AVCaptureSession audio frames with pause/resume PTS offset adjustments.
private final class RecordingSampleBufferHandler: NSObject, SCStreamOutput, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var isPaused = false
    private var pauseStartPTS: CMTime?
    private var accumulatedPauseDuration: CMTime = .zero
    private var sessionStarted = false
    private var sessionStartPTS: CMTime?
    
    private weak var writer: AVAssetWriter?
    private weak var videoInput: AVAssetWriterInput?
    private weak var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private weak var audioInput: AVAssetWriterInput?
    
    var isMicActive: Bool = false

    init(
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor,
        audioInput: AVAssetWriterInput? = nil
    ) {
        self.writer = writer
        self.videoInput = videoInput
        self.pixelAdaptor = pixelAdaptor
        self.audioInput = audioInput
    }

    func pause() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPaused else { return }
        isPaused = true
        pauseStartPTS = CMClockGetTime(CMClockGetHostTimeClock())
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard isPaused else { return }
        isPaused = false
        if let startPTS = pauseStartPTS {
            let currentPTS = CMClockGetTime(CMClockGetHostTimeClock())
            let pauseDelta = CMTimeSubtract(currentPTS, startPTS)
            accumulatedPauseDuration = CMTimeAdd(accumulatedPauseDuration, pauseDelta)
            pauseStartPTS = nil
        }
    }

    // MARK: - SCStreamOutput (Video Frames)
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }

        // Filter out non-complete frames
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
           let statusRaw = attachments.first?[.status] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw), status != .complete {
            return
        }

        lock.lock()
        if isPaused {
            lock.unlock()
            return
        }

        let rawPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let adjustedPTS = CMTimeSubtract(rawPTS, accumulatedPauseDuration)

        let localWriter = writer
        let localVideoInput = videoInput
        let localPixelAdaptor = pixelAdaptor
        let started = sessionStarted
        lock.unlock()

        guard let writer = localWriter, let videoInput = localVideoInput, let pixelAdaptor = localPixelAdaptor,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        if !started {
            lock.lock()
            if !sessionStarted {
                writer.startWriting()
                writer.startSession(atSourceTime: adjustedPTS)
                sessionStarted = true
                sessionStartPTS = adjustedPTS
            }
            lock.unlock()
        }

        if videoInput.isReadyForMoreMediaData {
            pixelAdaptor.append(pixelBuffer, withPresentationTime: adjustedPTS)
        }
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate (Audio Frames)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard sampleBuffer.isValid else { return }

        lock.lock()
        let micActive = isMicActive
        let paused = isPaused
        let pauseDuration = accumulatedPauseDuration
        let startPTS = sessionStartPTS
        let localWriter = writer
        let localAudioInput = audioInput
        lock.unlock()

        guard micActive, !paused, let writer = localWriter, let audioInput = localAudioInput, let sessionStartPTS = startPTS else {
            return
        }

        let rawPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let adjustedPTS = CMTimeSubtract(rawPTS, pauseDuration)

        // Drop audio frames before video session start time to ensure AV sync
        guard adjustedPTS >= sessionStartPTS else { return }

        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: adjustedPTS,
            decodeTimeStamp: .invalid
        )

        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )

        if status == noErr, let bufferToAppend = adjustedBuffer, writer.status == .writing, audioInput.isReadyForMoreMediaData {
            audioInput.append(bufferToAppend)
        }
    }
}

@MainActor
public final class ScreenRecorder: NSObject, ObservableObject {
    @Published public var state: RecordingState = .idle
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var isMicEnabled: Bool = false {
        didSet {
            sampleHandler?.isMicActive = isMicEnabled
        }
    }
    @Published public var recordMode: RecordMode = .fullScreen()
    @Published public var exportFormat: ExportFormat = .mp4
    public var simulatedPermissionGranted: Bool = true

    private var stream: SCStream?
    private var sampleHandler: RecordingSampleBufferHandler?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?

    private var audioCaptureSession: AVCaptureSession?
    private var audioDataOutput: AVCaptureAudioDataOutput?

    private var timer: Timer?
    private var startTime: Date?
    private var pauseStartTime: Date?
    private var totalPauseTimeInterval: TimeInterval = 0

    private var tempVideoURL: URL?
    private var finalTargetURL: URL?

    public override init() {
        super.init()
    }

    // MARK: - Static Dimension & Bitrate Utilities

    /// Snaps a point dimension scaled by screen factor to an even integer pixel size (min 2).
    public nonisolated static func snapToEven(value: CGFloat, scale: CGFloat) -> Int {
        let raw = Int(round(value * scale))
        return max(2, raw & ~1)
    }

    /// Snaps width and height of a point size to even pixel dimensions.
    public nonisolated static func snapToEven(points: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        let w = snapToEven(value: points.width, scale: scale)
        let h = snapToEven(value: points.height, scale: scale)
        return (w, h)
    }

    /// Snaps size to even dimensions returning a CGSize.
    public nonisolated static func snapToEvenDimensions(_ size: CGSize, scale: CGFloat = 1.0) -> CGSize {
        let (w, h) = snapToEven(points: size, scale: scale)
        return CGSize(width: CGFloat(w), height: CGFloat(h))
    }

    /// Dynamically calculates H.264 video bitrate based on pixel dimensions and target frame rate.
    public nonisolated static func calculateBitrate(width: Int, height: Int, fps: Int) -> Int {
        let pixels = width * height
        let bitsPerPixel: Double = (fps >= 30) ? 0.15 : 0.10
        let estimated = Int(Double(pixels * fps) * bitsPerPixel)
        return max(1_500_000, min(estimated, 20_000_000))
    }

    // MARK: - Public Recording Lifecycle

    /// Synchronous startRecording overload for harness/test compatibility.
    public func startRecording(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard simulatedPermissionGranted else {
            completion?(.failure(ScreenRecorderError.permissionDenied))
            return
        }
        if case .region(let rect, _) = recordMode {
            if rect.width < 1 || rect.height < 1 {
                completion?(.failure(ScreenRecorderError.invalidRegion))
                return
            }
        }
        guard state == .idle else {
            completion?(.failure(ScreenRecorderError.alreadyRecording))
            return
        }
        state = .recording
        elapsedTime = 0
        completion?(.success(()))
    }

    /// Starts screen recording with given mode, export format, and audio preference.
    public func startRecording(
        mode: RecordMode = .fullScreen(),
        format: ExportFormat = .mp4,
        includeMic: Bool = false
    ) async throws {
        guard state == .idle else {
            throw ScreenRecorderError.alreadyRecording
        }

        guard CaptureEngine.hasScreenRecordingPermission() else {
            throw ScreenRecorderError.permissionDenied
        }

        self.recordMode = mode
        self.exportFormat = format
        self.isMicEnabled = includeMic

        // 1. Fetch Shareable Content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenRecorderError.streamStartFailed(error.localizedDescription)
        }

        guard !content.displays.isEmpty else {
            throw ScreenRecorderError.noDisplayFound
        }

        // 2. Resolve Target Display
        let targetDisplayID: CGDirectDisplayID
        switch mode {
        case .fullScreen(let id):
            targetDisplayID = id ?? CGMainDisplayID()
        case .region(_, let id):
            targetDisplayID = id ?? CGMainDisplayID()
        }

        let targetDisplay = content.displays.first(where: { $0.displayID == targetDisplayID }) ?? content.displays[0]
        let displayBounds = CGDisplayBounds(targetDisplay.displayID)

        let scale = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == targetDisplay.displayID
        })?.backingScaleFactor ?? 2.0

        // 3. Compute Dimensions & Source Rect
        let sourceRectInDisplay: CGRect
        let pixelWidth: Int
        let pixelHeight: Int

        switch mode {
        case .fullScreen:
            sourceRectInDisplay = CGRect(origin: .zero, size: displayBounds.size)
            (pixelWidth, pixelHeight) = ScreenRecorder.snapToEven(points: displayBounds.size, scale: scale)
        case .region(let globalCocoaRect, _):
            sourceRectInDisplay = CaptureGeometry.topLeftSourceRect(
                selectionGlobalCocoa: globalCocoaRect,
                displayCocoaFrame: displayBounds
            )
            (pixelWidth, pixelHeight) = ScreenRecorder.snapToEven(points: sourceRectInDisplay.size, scale: scale)
        }

        let fps = (format == .gif) ? 15 : 30

        // 4. Configure Output File & AVAssetWriter
        let tempFileName = "ctdoshot_rec_\(UUID().uuidString).mp4"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
        self.tempVideoURL = tempURL

        let finalFileName = "ctdoshot_rec_\(UUID().uuidString).\(format == .gif ? "gif" : "mp4")"
        self.finalTargetURL = FileManager.default.temporaryDirectory.appendingPathComponent(finalFileName)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
        } catch {
            throw ScreenRecorderError.assetWriterCreationFailed
        }
        self.assetWriter = writer

        let videoBitrate = ScreenRecorder.calculateBitrate(width: pixelWidth, height: pixelHeight, fps: fps)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps * 2
            ]
        ]

        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        self.videoInput = vInput

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: pixelWidth,
            kCVPixelBufferHeightKey as String: pixelHeight
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )
        self.pixelAdaptor = adaptor

        if writer.canAdd(vInput) {
            writer.add(vInput)
        }

        // 5. Optional Microphone Audio Setup
        var aInput: AVAssetWriterInput? = nil
        if includeMic {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ]
            let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput.expectsMediaDataInRealTime = true
            if writer.canAdd(audioWriterInput) {
                writer.add(audioWriterInput)
                aInput = audioWriterInput
                self.audioInput = audioWriterInput
            }
            try? setupMicrophoneSession()
        }

        // 6. Create Stream Sample Handler
        let handler = RecordingSampleBufferHandler(
            writer: writer,
            videoInput: vInput,
            pixelAdaptor: adaptor,
            audioInput: aInput
        )
        handler.isMicActive = includeMic
        self.sampleHandler = handler

        // Attach handler to Microphone Audio Output if present
        if let audioOutput = self.audioDataOutput {
            audioOutput.setSampleBufferDelegate(handler, queue: DispatchQueue(label: "com.ctdoshot.micAudioQueue", qos: .userInitiated))
        }

        // 7. Configure ScreenCaptureKit Stream
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
        let streamConfig = SCStreamConfiguration()
        streamConfig.showsCursor = true
        streamConfig.queueDepth = 6
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        streamConfig.sourceRect = sourceRectInDisplay
        streamConfig.width = pixelWidth
        streamConfig.height = pixelHeight
        streamConfig.destinationRect = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)

        let scStream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        do {
            try scStream.addStreamOutput(handler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.ctdoshot.scStreamQueue", qos: .userInitiated))
        } catch {
            throw ScreenRecorderError.streamStartFailed(error.localizedDescription)
        }
        self.stream = scStream

        // 8. Start Stream & Audio Session
        do {
            try await scStream.startCapture()
        } catch {
            throw ScreenRecorderError.streamStartFailed(error.localizedDescription)
        }

        if let audioSession = self.audioCaptureSession {
            audioSession.startRunning()
        }

        // 9. Update State & Timer
        self.startTime = Date()
        self.totalPauseTimeInterval = 0
        self.elapsedTime = 0
        self.state = .recording

        startTimer()
    }

    /// Pauses current recording.
    public func pauseRecording() {
        guard state == .recording else { return }
        sampleHandler?.pause()
        pauseStartTime = Date()
        state = .paused
    }

    /// Resumes active recording.
    public func resumeRecording() {
        guard state == .paused else { return }
        if let pauseStart = pauseStartTime {
            totalPauseTimeInterval += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        sampleHandler?.resume()
        state = .recording
    }

    /// Toggles microphone audio recording dynamically.
    public func toggleMic() {
        isMicEnabled.toggle()
    }

    /// Stops recording and returns URL of output MP4 or converted GIF file.
    public func stopRecording() async throws -> URL {
        guard state == .recording || state == .paused else {
            throw ScreenRecorderError.notRecording
        }

        state = .stopping
        stopTimer()

        // 1. Stop Audio Session & Stream
        if let audioSession = self.audioCaptureSession, audioSession.isRunning {
            audioSession.stopRunning()
        }

        if let scStream = self.stream {
            try? await scStream.stopCapture()
            self.stream = nil
        }

        // 2. Finish AVAssetWriter
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        if let writer = assetWriter, writer.status == .writing {
            await writer.finishWriting()
        }

        guard let tempMP4URL = tempVideoURL, FileManager.default.fileExists(atPath: tempMP4URL.path) else {
            self.state = .idle
            throw ScreenRecorderError.assetWriterCreationFailed
        }

        let targetURL = finalTargetURL ?? tempMP4URL

        // 3. If GIF format requested, convert temp MP4 to GIF
        if exportFormat == .gif {
            let converter = GIFConverter()
            do {
                _ = try await converter.convert(mp4URL: tempMP4URL, outputURL: targetURL)
                try? FileManager.default.removeItem(at: tempMP4URL)
            } catch {
                try? FileManager.default.removeItem(at: tempMP4URL)
                self.state = .idle
                throw error
            }
        }

        self.state = .idle
        return targetURL
    }

    /// Closure completion wrapper for stopRecording.
    public func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let url = try await stopRecording()
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private Helpers

    private func setupMicrophoneSession() throws {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard authStatus == .authorized || authStatus == .notDetermined else {
            return
        }

        guard let micDevice = AVCaptureDevice.default(for: .audio) else {
            return
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        guard let micInput = try? AVCaptureDeviceInput(device: micDevice), session.canAddInput(micInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(micInput)

        let audioOutput = AVCaptureAudioDataOutput()
        guard session.canAddOutput(audioOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(audioOutput)
        session.commitConfiguration()

        self.audioCaptureSession = session
        self.audioDataOutput = audioOutput
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedTime() {
        guard state == .recording, let start = startTime else { return }
        elapsedTime = max(0, Date().timeIntervalSince(start) - totalPauseTimeInterval)
    }
}
