//
//  StreamenCloudDevicesView.swift
//  Streamen
//
//  The Streamen Cloud account's devices with platform and last seen, fetched live.
//  Other devices can be removed; this one leaves through Leave Streamen Cloud.
//  The server stores last seen once per day, so it reads as a date.
//

import SwiftUI

#if !os(tvOS)

    struct StreamenCloudDevicesView: View {
        @Environment(CloudSyncCoordinator.self) private var coordinator: CloudSyncCoordinator?
        @State private var model = StreamenCloudDevicesModel()

        var body: some View {
            Form {
                if let devices = model.devices {
                    Section {
                        ForEach(devices) { device in
                            row(for: device)
                        }
                    } footer: {
                        Text("To remove this device, leave Streamen Cloud instead.")
                    }
                } else if model.errorMessage == nil {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let errorMessage = model.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                        if model.devices == nil {
                            Button("Try Again") {
                                Task { await model.load(using: coordinator) }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .settingsBackButton()
            .platformNavigationTitle("Devices")
            .task { await model.load(using: coordinator) }
            .refreshable { await model.load(using: coordinator) }
            .macRefreshButton(disabled: model.isLoading || model.removingID != nil) {
                await model.load(using: coordinator)
            }
            .alert(
                removalTitle,
                isPresented: $model.isRemovalPresented,
                presenting: model.pendingRemoval
            ) { device in
                Button("Remove", role: .destructive) {
                    Task { await model.remove(device, using: coordinator) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It stops syncing with Streamen Cloud. Anything already on it stays there.")
            }
        }

        private var removalTitle: Text {
            guard let name = model.pendingRemoval?.name else { return Text(verbatim: "") }
            return Text("Remove “\(name)”?")
        }

        @ViewBuilder
        private func row(for device: StreamenCloudDeviceInfo) -> some View {
            if device.isCurrent {
                StreamenCloudDeviceRow(device: device, isRemoving: false, onRemove: nil)
            } else {
                StreamenCloudDeviceRow(
                    device: device,
                    isRemoving: model.removingID == device.id,
                    onRemove: { model.pendingRemoval = device }
                )
                .swipeActions(edge: .trailing) {
                    Button("Remove", role: .destructive) { model.pendingRemoval = device }
                }
                .contextMenu {
                    Button("Remove", systemImage: "trash", role: .destructive) { model.pendingRemoval = device }
                }
            }
        }
    }

    private extension View {
        /// `.refreshable` does nothing on macOS, so the list reloads from a
        /// button under it there — not the toolbar, which in the Settings
        /// window holds its tabs and never delivers the click.
        @ViewBuilder
        func macRefreshButton(disabled: Bool, action: @escaping () async -> Void) -> some View {
            #if os(macOS)
                safeAreaInset(edge: .bottom) {
                    HStack {
                        Spacer()
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await action() }
                        }
                        .disabled(disabled)
                    }
                    .padding(12)
                }
            #else
                self
            #endif
        }
    }

    /// One device: name, platform and last seen. macOS rows have no swipe, so
    /// removable rows there carry a visible button besides the context menu.
    private struct StreamenCloudDeviceRow: View {
        let device: StreamenCloudDeviceInfo
        let isRemoving: Bool
        let onRemove: (() -> Void)?

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: StreamenCloudPlatformName.symbolName(for: device.platform))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: device.name)
                    HStack(spacing: 4) {
                        Text(verbatim: StreamenCloudPlatformName.displayName(for: device.platform))
                        Text(verbatim: "·")
                            .accessibilityHidden(true)
                        if device.isCurrent {
                            Text("This Device")
                        } else {
                            Text("Last seen \(Text(device.lastSeen, format: .dateTime.day().month().year()))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                if isRemoving {
                    ProgressView()
                        .controlSize(.small)
                }
                #if os(macOS)
                    if let onRemove, !isRemoving {
                        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Remove")
                    }
                #endif
            }
        }
    }

#endif
