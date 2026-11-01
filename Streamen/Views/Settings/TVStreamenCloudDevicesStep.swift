//
//  TVStreamenCloudDevicesStep.swift
//  Streamen
//
//  The tvOS Sync pane's device list, shown in place (see
//  TVStreamenCloudPairingSteps). Select on another device asks to remove it; this
//  device leaves through Leave Streamen Cloud instead. No `.contextMenu`: a held
//  Select in a Settings pane returns focus to the rail.
//

#if os(tvOS)

    import SwiftUI

    struct TVStreamenCloudDevicesStep: View {
        @Environment(CloudSyncCoordinator.self) private var coordinator: CloudSyncCoordinator?
        @State private var model = StreamenCloudDevicesModel()
        @State private var showsCurrentDeviceNote = false
        @FocusState private var focus: Row?

        private enum Row: Hashable {
            /// This device's row, there from the first frame (a placeholder
            /// until the list lands) so the step always holds focus.
            case current
            case device(UUID)
            case retry
        }

        private var currentDevice: StreamenCloudDeviceInfo? {
            model.devices?.first(where: \.isCurrent)
        }

        private var otherDevices: [StreamenCloudDeviceInfo] {
            model.devices?.filter { !$0.isCurrent } ?? []
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                TVSettingsSectionLabel("Devices")

                currentDeviceRow

                ForEach(otherDevices) { device in
                    Button {
                        model.pendingRemoval = device
                    } label: {
                        TVStreamenCloudDeviceLabel(
                            name: device.name,
                            platform: device.platform,
                            isCurrent: false,
                            lastSeen: device.lastSeen,
                            isBusy: model.removingID == device.id
                        )
                    }
                    .buttonStyle(TVSettingsRowButtonStyle())
                    .focused($focus, equals: .device(device.id))
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .tvStreamenCloudFootnote(isError: true)
                        .padding(.top, 4)

                    if model.devices == nil {
                        TVStreamenCloudActionRow("Try Again", systemImage: "arrow.clockwise") {
                            Task { await model.load(using: coordinator) }
                        }
                        .focused($focus, equals: .retry)
                    }
                }

                Text("To remove this device, leave Streamen Cloud instead.")
                    .tvStreamenCloudFootnote()
                    .padding(.top, 8)
            }
            .task { await model.load(using: coordinator) }
            .onAppear {
                Task { @MainActor in focus = .current }
            }
            .alert(
                removalTitle,
                isPresented: $model.isRemovalPresented,
                presenting: model.pendingRemoval
            ) { device in
                Button("Remove", role: .destructive) { remove(device) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It stops syncing with Streamen Cloud. Anything already on it stays there.")
            }
        }

        private var currentDeviceRow: some View {
            Button {
                showsCurrentDeviceNote = true
            } label: {
                TVStreamenCloudDeviceLabel(
                    name: currentDevice?.name ?? coordinator?.streamenCloudDeviceName ?? "",
                    platform: currentDevice?.platform ?? "tvos",
                    isCurrent: true,
                    lastSeen: nil,
                    isBusy: model.devices == nil && model.errorMessage == nil
                )
            }
            .buttonStyle(TVSettingsRowButtonStyle())
            .focused($focus, equals: .current)
            .alert("This Device", isPresented: $showsCurrentDeviceNote) {
                Button("OK") {}
            } message: {
                Text("To remove this device, leave Streamen Cloud instead.")
            }
        }

        private var removalTitle: Text {
            guard let name = model.pendingRemoval?.name else { return Text(verbatim: "") }
            return Text("Remove “\(name)”?")
        }

        /// The removed row goes away, so focus moves to this device's row.
        private func remove(_ device: StreamenCloudDeviceInfo) {
            Task {
                await model.remove(device, using: coordinator)
                if model.devices?.contains(where: { $0.id == device.id }) == false {
                    focus = .current
                }
            }
        }
    }

    /// A device row's content: platform symbol, name, and platform with last
    /// seen (a date: the server stores it once per day).
    private struct TVStreamenCloudDeviceLabel: View {
        let name: String
        let platform: String
        let isCurrent: Bool
        let lastSeen: Date?
        let isBusy: Bool

        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: StreamenCloudPlatformName.symbolName(for: platform))
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: name)
                    HStack(spacing: 6) {
                        Text(verbatim: StreamenCloudPlatformName.displayName(for: platform))
                        Text(verbatim: "·")
                            .accessibilityHidden(true)
                        if isCurrent {
                            Text("This Device")
                        } else if let lastSeen {
                            Text("Last seen \(Text(lastSeen, format: .dateTime.day().month().year()))")
                        }
                    }
                    .font(.system(size: TVSettingsMetrics.secondaryFontSize))
                    .opacity(0.7)
                }
                Spacer(minLength: 0)
                if isBusy { ProgressView() }
            }
        }
    }

#endif
