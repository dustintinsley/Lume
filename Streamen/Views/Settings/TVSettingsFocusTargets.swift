//
//  TVSettingsFocusTargets.swift
//  Streamen
//
//  The focus targets the tvOS Settings pane hands focus back to: the rows
//  that open sub-pages, and where focus goes after Content Management swaps
//  the pane.
//

#if os(tvOS)
    import Foundation

    /// Where focus goes once Content Management has swapped the whole pane in
    /// or out.
    enum TVSettingsPaneHandoff {
        case contentManagement
        case drillIn(TVSettingsDrillIn)
    }

    /// A row that opens a sub-page in the Settings pane, focused again when
    /// Menu backs out of it.
    enum TVSettingsDrillIn: Hashable {
        case playlist(UUID)
        case contentManagement
        case recordingServer
        case audioLanguages, addLanguage
        case subtitleStyle, openSubtitles, philipsHue
        case engines
        case engineOptions(PlayerEngineKind)
        case syncBackend(SyncBackendSelection)
        case streamenCloudDeviceName, streamenCloudAddDevice, streamenCloudDevices, streamenCloudRecoveryKey
    }
#endif
