//
//  StreamenEngineSettingsViews.swift
//  Streamen
//
//  The Streamen Engine's option surface in Settings, split out of
//  `PlayerEngineSettingsViews.swift` so the shared file stays under the
//  file-length limit. Same two presentations as the other engines: a grouped
//  `Form` section for iOS/macOS and the flat Apple-TV-style detail block for
//  tvOS.
//
//  Every control is backed directly by `@AppStorage`, read back by the
//  coordinator through `StreamenEngineOptions` the next time a stream starts.
//

import SwiftUI

// MARK: - iOS / macOS form

#if !os(tvOS)

    /// Streamen Engine options as a grouped `Form` section.
    struct StreamenEngineSettingsForm: View {
        @AppStorage(PlayerSettings.Streamen.hardwareDecodeKey) private var hardwareDecode = PlayerSettings.Streamen.hardwareDecodeDefault
        @AppStorage(PlayerSettings.Streamen.deinterlaceModeKey) private var deinterlaceMode = StreamenDeinterlaceMode.defaultValue.rawValue
        @AppStorage(PlayerSettings.Streamen.deinterlaceRateKey) private var deinterlaceRate = StreamenDeinterlaceRate.defaultValue.rawValue
        @AppStorage(PlayerSettings.Streamen.httpReconnectKey) private var httpReconnect = PlayerSettings.Streamen.httpReconnectDefault
        @AppStorage(PlayerSettings.Streamen.liveBufferKey) private var liveBuffer = PlayerSettings.Streamen.liveBufferDefault
        @AppStorage(PlayerSettings.Streamen.vodBufferKey) private var vodBuffer = PlayerSettings.Streamen.vodBufferDefault
        @AppStorage(PlayerSettings.Streamen.videoQueueDepthKey) private var videoQueueDepth = PlayerSettings.Streamen.videoQueueDepthDefault
        @AppStorage(PlayerSettings.Streamen.audioQueueDepthKey) private var audioQueueDepth = PlayerSettings.Streamen.audioQueueDepthDefault
        @AppStorage(PlayerSettings.Streamen.stallThresholdKey) private var stallThreshold = PlayerSettings.Streamen.stallThresholdDefault
        @AppStorage(PlayerSettings.Streamen.ioTimeoutKey) private var ioTimeout = StreamenIOTimeout.defaultValue.rawValue
        @AppStorage(PlayerSettings.Streamen.probeSizeKey) private var probeSize = StreamenProbeSize.auto.rawValue
        @AppStorage(PlayerSettings.Streamen.analyzeDurationKey) private var analyzeDuration = StreamenAnalyzeDuration.auto.rawValue

        @State private var showResetConfirmation = false

        var body: some View {
            Section {
                Toggle("Hardware Decoding", isOn: $hardwareDecode)

                Picker("Deinterlace", selection: $deinterlaceMode) {
                    ForEach(StreamenDeinterlaceMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                if deinterlaceMode != StreamenDeinterlaceMode.off.rawValue {
                    Picker("Frame Rate", selection: $deinterlaceRate) {
                        ForEach(StreamenDeinterlaceRate.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                }

                Picker("Video Queue Depth", selection: $videoQueueDepth) {
                    ForEach(StreamenVideoQueuePreset.values, id: \.self) { Text(StreamenVideoQueuePreset.label($0)).tag($0) }
                }
                Picker("Audio Queue Depth", selection: $audioQueueDepth) {
                    ForEach(StreamenAudioQueuePreset.values, id: \.self) { Text(StreamenAudioQueuePreset.label($0)).tag($0) }
                }

                Toggle("HTTP Reconnect", isOn: $httpReconnect)

                Picker("Live Buffer", selection: $liveBuffer) {
                    ForEach(StreamenBufferPreset.values, id: \.self) { Text(StreamenBufferPreset.label($0)).tag($0) }
                }
                Picker("On-Demand Buffer", selection: $vodBuffer) {
                    ForEach(StreamenBufferPreset.values, id: \.self) { Text(StreamenBufferPreset.label($0)).tag($0) }
                }

                Picker("Stall Detection", selection: $stallThreshold) {
                    ForEach(StreamenStallThresholdPreset.values, id: \.self) { Text(StreamenStallThresholdPreset.label($0)).tag($0) }
                }
                Picker("Network Timeout", selection: $ioTimeout) {
                    ForEach(StreamenIOTimeout.allCases) { Text($0.label).tag($0.rawValue) }
                }

                Picker("Probe Size", selection: $probeSize) {
                    ForEach(StreamenProbeSize.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker("Analyze Duration", selection: $analyzeDuration) {
                    ForEach(StreamenAnalyzeDuration.allCases) { Text($0.label).tag($0.rawValue) }
                }
            } footer: {
                Text("Deinterlacing removes the combing interlaced broadcasts — most live sport — show on motion, without giving up hardware decoding. ")
                    + Text("Automatic filters only streams that report interlaced frames; choose Always for providers that don't. Doubling the frame rate smooths motion at a higher cost. ")
                    + Text("The buffers set how much decoded media is held before playback starts or resumes — raise them if high-bitrate 4K streams stutter. ")
                    + Text("Queue depths trade memory for smoothness: decoded 4K video frames are large, so raise the video queue cautiously. Applied the next time playback starts.")
            }

            Section {
                Button("Restore Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
            }
            .confirmationDialog(
                "Restore the default Streamen Engine options?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore Defaults", role: .destructive) {
                    PlayerSettings.Streamen.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    /// Dedicated screen wrapping the Streamen Engine options, pushed from the Player
    /// settings section so every engine's options are reachable regardless of
    /// the priority order.
    struct StreamenEngineSettingsScreen: View {
        var body: some View {
            Form {
                StreamenEngineSettingsForm()
            }
            .platformNavigationTitle("Streamen Engine Options")
        }
    }

#endif

// MARK: - tvOS detail

#if os(tvOS)

    /// Streamen Engine options for the tvOS settings detail pane.
    struct StreamenEngineSettingsTVDetail: View {
        @AppStorage(PlayerSettings.Streamen.hardwareDecodeKey) private var hardwareDecode = PlayerSettings.Streamen.hardwareDecodeDefault
        @AppStorage(PlayerSettings.Streamen.deinterlaceModeKey) private var deinterlaceMode = StreamenDeinterlaceMode.defaultValue.rawValue
        @AppStorage(PlayerSettings.Streamen.deinterlaceRateKey) private var deinterlaceRate = StreamenDeinterlaceRate.defaultValue.rawValue
        @AppStorage(PlayerSettings.Streamen.httpReconnectKey) private var httpReconnect = PlayerSettings.Streamen.httpReconnectDefault
        @AppStorage(PlayerSettings.Streamen.liveBufferKey) private var liveBuffer = PlayerSettings.Streamen.liveBufferDefault
        @AppStorage(PlayerSettings.Streamen.vodBufferKey) private var vodBuffer = PlayerSettings.Streamen.vodBufferDefault
        @AppStorage(PlayerSettings.Streamen.videoQueueDepthKey) private var videoQueueDepth = PlayerSettings.Streamen.videoQueueDepthDefault
        @AppStorage(PlayerSettings.Streamen.audioQueueDepthKey) private var audioQueueDepth = PlayerSettings.Streamen.audioQueueDepthDefault
        @AppStorage(PlayerSettings.Streamen.stallThresholdKey) private var stallThreshold = PlayerSettings.Streamen.stallThresholdDefault
        @AppStorage(PlayerSettings.Streamen.ioTimeoutKey) private var ioTimeout = StreamenIOTimeout.defaultValue.rawValue
        @AppStorage(PlayerSettings.Streamen.probeSizeKey) private var probeSize = StreamenProbeSize.auto.rawValue
        @AppStorage(PlayerSettings.Streamen.analyzeDurationKey) private var analyzeDuration = StreamenAnalyzeDuration.auto.rawValue

        @State private var showResetConfirmation = false

        var body: some View {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    TVSettingsSectionLabel("Streamen Engine — Decoding")
                    TVOptionToggleRow(title: "Hardware Decoding", isOn: $hardwareDecode)
                    TVOptionCycleRow(
                        title: "Deinterlace",
                        valueLabel: (StreamenDeinterlaceMode(rawValue: deinterlaceMode) ?? .defaultValue).label
                    ) { deinterlaceMode = PlayerOptionCycle.next(deinterlaceMode, in: StreamenDeinterlaceMode.self) }
                    if deinterlaceMode != StreamenDeinterlaceMode.off.rawValue {
                        TVOptionCycleRow(
                            title: "Frame Rate",
                            valueLabel: (StreamenDeinterlaceRate(rawValue: deinterlaceRate) ?? .defaultValue).label
                        ) { deinterlaceRate = PlayerOptionCycle.next(deinterlaceRate, in: StreamenDeinterlaceRate.self) }
                    }
                    TVOptionCycleRow(title: "Video Queue Depth", valueLabel: StreamenVideoQueuePreset.label(videoQueueDepth)) {
                        videoQueueDepth = PlayerOptionCycle.next(videoQueueDepth, in: StreamenVideoQueuePreset.values)
                    }
                    TVOptionCycleRow(title: "Audio Queue Depth", valueLabel: StreamenAudioQueuePreset.label(audioQueueDepth)) {
                        audioQueueDepth = PlayerOptionCycle.next(audioQueueDepth, in: StreamenAudioQueuePreset.values)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    TVSettingsSectionLabel("Streamen Engine — Network & Buffering")
                    TVOptionToggleRow(title: "HTTP Reconnect", isOn: $httpReconnect)
                    TVOptionCycleRow(title: "Live Buffer", valueLabel: StreamenBufferPreset.label(liveBuffer)) {
                        liveBuffer = PlayerOptionCycle.next(liveBuffer, in: StreamenBufferPreset.values)
                    }
                    TVOptionCycleRow(title: "On-Demand Buffer", valueLabel: StreamenBufferPreset.label(vodBuffer)) {
                        vodBuffer = PlayerOptionCycle.next(vodBuffer, in: StreamenBufferPreset.values)
                    }
                    TVOptionCycleRow(title: "Stall Detection", valueLabel: StreamenStallThresholdPreset.label(stallThreshold)) {
                        stallThreshold = PlayerOptionCycle.next(stallThreshold, in: StreamenStallThresholdPreset.values)
                    }
                    TVOptionCycleRow(
                        title: "Network Timeout",
                        valueLabel: (StreamenIOTimeout(rawValue: ioTimeout) ?? .defaultValue).label
                    ) { ioTimeout = PlayerOptionCycle.next(ioTimeout, in: StreamenIOTimeout.self) }
                }

                VStack(alignment: .leading, spacing: 8) {
                    TVSettingsSectionLabel("Streamen Engine — Stream Analysis")
                    TVOptionCycleRow(
                        title: "Probe Size",
                        valueLabel: (StreamenProbeSize(rawValue: probeSize) ?? .auto).label
                    ) { probeSize = PlayerOptionCycle.next(probeSize, in: StreamenProbeSize.self) }
                    TVOptionCycleRow(
                        title: "Analyze Duration",
                        valueLabel: (StreamenAnalyzeDuration(rawValue: analyzeDuration) ?? .auto).label
                    ) { analyzeDuration = PlayerOptionCycle.next(analyzeDuration, in: StreamenAnalyzeDuration.self) }
                }

                TVOptionResetRow(title: "Restore Defaults") { showResetConfirmation = true }
            }
            .confirmationDialog(
                "Restore the default Streamen Engine options?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore Defaults", role: .destructive) {
                    PlayerSettings.Streamen.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

#endif
