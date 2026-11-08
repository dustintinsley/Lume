//
//  AppIconPickerSection.swift
//  Streamen
//
//  Settings › Appearance › App Icon: the twelve colourways as a grid of icon
//  tiles, dark backgrounds then light. iOS and macOS only;
//  the choice itself lives in `AppIconChoice`.
//

#if os(iOS) || os(macOS)

    import SwiftUI

    struct AppIconPickerSection: View {
        @AppStorage(AppIconChoice.storageKey)
        private var appIconRaw = AppIconChoice.defaultValue.rawValue

        private var selection: AppIconChoice {
            AppIconChoice.resolve(appIconRaw)
        }

        var body: some View {
            Section {
                grid(AppIconChoice.darkColorways)
                grid(AppIconChoice.lightColorways)
            } header: {
                Text("App Icon")
            } footer: {
                #if os(macOS)
                    Text("Sets the Dock icon while Streamen is open.")
                #endif
            }
        }

        private func grid(_ choices: [AppIconChoice]) -> some View {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 84), spacing: 8)], spacing: 12) {
                ForEach(choices) { choice in
                    AppIconTile(choice: choice, isSelected: choice == selection) {
                        appIconRaw = choice.rawValue
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    /// One icon option: its artwork, its name, and a ring when selected.
    private struct AppIconTile: View {
        let choice: AppIconChoice
        let isSelected: Bool
        let action: () -> Void

        private let side: CGFloat = 56
        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
        }

        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(choice.artworkName).resizable().scaledToFill()
                        .frame(width: side, height: side)
                        .clipShape(shape)
                        .overlay { shape.strokeBorder(.primary.opacity(0.12)) }
                        .padding(3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                .opacity(isSelected ? 1 : 0)
                        }
                    Text(choice.title)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(choice.title))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }

#endif
