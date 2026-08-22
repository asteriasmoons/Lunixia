//
//  JournalBackgroundSettingsSheet.swift
//  Lunixia
//

import SwiftUI
import PhotosUI

struct JournalBackgroundSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: JournalEntry

    @State private var showPhotoPicker = false
    @State private var showCoverPhotoPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: - Header

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                GradientTitle(text: "entry background", size: 30)
                                Text("Customize the background appearance behind your journal entry.")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // MARK: - Cover Image

                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {

                                Text("Cover Image")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                if let data = entry.coverImageData,
                                   let uiImage = UIImage(data: data) {

                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 160)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Vertical Position")
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(verticalOffsetLabel)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        Slider(
                                            value: $entry.coverImageVerticalOffset,
                                            in: -1.0...1.0
                                        )
                                        .tint(LColors.accent)
                                    }
                                }

                                Button {
                                    showCoverPhotoPicker = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image("image")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 17, height: 17)
                                        Text(entry.coverImageData == nil
                                             ? "Add Cover Image"
                                             : "Replace Cover Image")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(LColors.accentGradient)
                                    )
                                }
                                .buttonStyle(.plain)

                                if entry.coverImageData != nil {
                                    Button(role: .destructive) {
                                        entry.coverImageData = nil
                                        entry.coverImageVerticalOffset = 0.0
                                        entry.touch()
                                    } label: {
                                        HStack {
                                            Image(systemName: "trash.fill")
                                            Text("Remove Cover Image")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // MARK: - Background Mode

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {

                                Text("Background Type")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Picker("", selection: backgroundModeBinding) {
                                    ForEach(JournalEntryBackgroundMode.allCases) { mode in
                                        Text(mode.title)
                                            .tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // MARK: - Solid Color

                        if entry.backgroundMode == .solidColor {

                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {

                                    Text("Background Color")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    ColorPicker(
                                        "Choose Color",
                                        selection: solidColorBinding,
                                        supportsOpacity: false
                                    )
                                    .foregroundStyle(.white.opacity(0.8))
                                    .tint(LColors.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // MARK: - Gradient

                        if entry.backgroundMode == .gradient {

                            GlassCard {
                                VStack(alignment: .leading, spacing: 16) {

                                    Text("Gradient Colors")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    VStack(alignment: .leading, spacing: 10) {

                                        Text("Start Color")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.72))

                                        ColorPicker(
                                            "Start",
                                            selection: gradientStartBinding,
                                            supportsOpacity: false
                                        )
                                        .labelsHidden()
                                    }

                                    VStack(alignment: .leading, spacing: 10) {

                                        Text("End Color")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.72))

                                        ColorPicker(
                                            "End",
                                            selection: gradientEndBinding,
                                            supportsOpacity: false
                                        )
                                        .labelsHidden()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // MARK: - Image

                        if entry.backgroundMode == .image {

                            GlassCard {
                                VStack(alignment: .leading, spacing: 18) {

                                    Text("Background Image")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if let data = entry.backgroundImageData,
                                       let uiImage = UIImage(data: data) {

                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 180)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 22,
                                                    style: .continuous
                                                )
                                            )
                                    }

                                    Button {
                                        showPhotoPicker = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image("image")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 17, height: 17)
                                            Text(entry.backgroundImageData == nil
                                                 ? "Choose Image"
                                                 : "Replace Image")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(
                                                cornerRadius: 18,
                                                style: .continuous
                                            )
                                            .fill(LColors.accentGradient)
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 10) {

                                        HStack {
                                            Text("Image Opacity")
                                                .foregroundStyle(.white)

                                            Spacer()

                                            Text("\(Int(entry.backgroundImageOpacity * 100))%")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Slider(
                                            value: $entry.backgroundImageOpacity,
                                            in: 0...1
                                        )
                                        .tint(LColors.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 10) {

                                        HStack {
                                            Text("Blur")
                                                .foregroundStyle(.white)

                                            Spacer()

                                            Text("\(Int(entry.backgroundImageBlur))")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Slider(
                                            value: $entry.backgroundImageBlur,
                                            in: 0...20
                                        )
                                        .tint(LColors.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 10) {

                                        HStack {
                                            Text("Dark Overlay")
                                                .foregroundStyle(.white)

                                            Spacer()

                                            Text("\(Int(entry.backgroundOverlayOpacity * 100))%")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Slider(
                                            value: $entry.backgroundOverlayOpacity,
                                            in: 0...1
                                        )
                                        .tint(LColors.accent)
                                    }

                                    if entry.backgroundImageData != nil {

                                        Button(role: .destructive) {
                                            entry.backgroundImageData = nil
                                            entry.touch()
                                        } label: {

                                            HStack {
                                                Image(systemName: "trash.fill")

                                                Text("Remove Image")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // MARK: - Reset

                        GlassCard {
                            Button {
                                resetBackground()
                            } label: {
                                HStack {
                                    Image("undo")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 17, height: 17)
                                    Text("Reset Background")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(LColors.glassSurface2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(LColors.accentGradient, lineWidth: 1.5)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPhotoPicker) {
                JournalBackgroundImagePickerSheet { data in
                    entry.backgroundImageData = data
                    entry.touch()
                }
            }
            .sheet(isPresented: $showCoverPhotoPicker) {
                JournalBackgroundImagePickerSheet { data in
                    entry.coverImageData = data
                    entry.touch()
                }
            }
        }
    }

    private var verticalOffsetLabel: String {
        let val = entry.coverImageVerticalOffset
        if val < -0.1 { return "Top" }
        if val > 0.1 { return "Bottom" }
        return "Center"
    }

    // MARK: - Bindings

    private var backgroundModeBinding: Binding<JournalEntryBackgroundMode> {
        Binding(
            get: { entry.backgroundMode },
            set: {
                entry.backgroundMode = $0
                entry.touch()
            }
        )
    }

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(lunixiaHex: entry.backgroundColorHex)
            },
            set: {
                entry.backgroundColorHex = Self.hexString(from: $0)
                entry.touch()
            }
        )
    }

    private var gradientStartBinding: Binding<Color> {
        Binding(
            get: {
                Color(lunixiaHex: entry.backgroundGradientStartHex)
            },
            set: {
                entry.backgroundGradientStartHex = Self.hexString(from: $0)
                entry.touch()
            }
        )
    }

    private var gradientEndBinding: Binding<Color> {
        Binding(
            get: {
                Color(lunixiaHex: entry.backgroundGradientEndHex)
            },
            set: {
                entry.backgroundGradientEndHex = Self.hexString(from: $0)
                entry.touch()
            }
        )
    }

    // MARK: - Actions

    private func resetBackground() {
        entry.backgroundMode = .defaultLystaria
        entry.backgroundColorHex = ""
        entry.backgroundGradientStartHex = ""
        entry.backgroundGradientEndHex = ""
        entry.backgroundImageData = nil
        entry.backgroundImageOpacity = 0.85
        entry.backgroundImageBlur = 0
        entry.backgroundOverlayOpacity = 0.35
        entry.touch()
    }

    // MARK: - Helpers

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#000000"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

// MARK: - Isolated photo picker

private struct JournalBackgroundImagePickerSheet: UIViewControllerRepresentable {
    let onImagePicked: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (Data) -> Void

        init(onImagePicked: @escaping (Data) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard
                        let image = object as? UIImage,
                        let data = image.jpegData(compressionQuality: 0.92)
                    else { return }

                    DispatchQueue.main.async {
                        self.onImagePicked(data)
                    }
                }
            }
        }
    }
}
