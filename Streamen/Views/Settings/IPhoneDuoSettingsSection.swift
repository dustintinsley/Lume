//
//  IPhoneDuoSettingsSection.swift
//  Streamen
//
//  Settings › Appearance › iPhone Duo: the folded-screen reflection under the
//  player on a half-folded iPhone (`FoldedReflectionView`). Shown on iPhone
//  only; the settings themselves live in `PlayerSettings.FoldedReflection`.
//

#if os(iOS)

    import SwiftUI

    struct IPhoneDuoSettingsSection: View {
        @AppStorage(PlayerSettings.FoldedReflection.enabledKey)
        private var foldedReflection = PlayerSettings.FoldedReflection.enabledDefault
        @AppStorage(PlayerSettings.FoldedReflection.blurKey)
        private var foldedReflectionBlur = PlayerSettings.FoldedReflection.blurDefault
        @AppStorage(PlayerSettings.FoldedReflection.strengthKey)
        private var foldedReflectionStrength = PlayerSettings.FoldedReflection.strengthDefault
        @AppStorage(PlayerSettings.FoldedReflection.fadeLengthKey)
        private var foldedReflectionFadeLength = PlayerSettings.FoldedReflection.fadeLengthDefault

        var body: some View {
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section {
                    Toggle("Folded Screen Reflection (Experimental)", isOn: $foldedReflection)

                    if foldedReflection {
                        Toggle("Blur Reflection", isOn: $foldedReflectionBlur)
                        percentSlider(
                            "Reflection Strength", value: $foldedReflectionStrength,
                            in: PlayerSettings.FoldedReflection.strengthRange
                        )
                        percentSlider(
                            "Fade Length", value: $foldedReflectionFadeLength,
                            in: PlayerSettings.FoldedReflection.fadeLengthRange
                        )
                    }
                } header: {
                    Text("iPhone Duo")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("When iPhone is half-folded, the video plays on the upper screen and a soft reflection of it appears on the lower screen, under the controls.")
                        if foldedReflection {
                            Text("Strength is how visible the reflection is at the fold. Fade Length is how far down the lower screen it fades out to nothing.")
                        }
                    }
                }
            }
        }

        private func percentSlider(
            _ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: value, in: range, step: 0.05)
            }
        }
    }

#endif
