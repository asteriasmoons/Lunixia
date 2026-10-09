//
//  HoroscopeView.swift
//  Lunixia
//

import SwiftUI

struct HoroscopeView: View {
    @Environment(\.appTheme) private var theme

    @Binding var selectedTab: HoroscopeTab
    @Binding var selectedSign: String

    let zodiacSigns: [String]

    let dailyHoroscope: DailyHoroscope?
    let previewHoroscope: DailyHoroscope?

    let isLoading: Bool
    let errorText: String?

    let onFetch: () -> Void
    let onClearPreview: () -> Void

    private var selectedZodiacAssetName: String {
        zodiacAssetName(for: selectedSign)
    }

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                horoscopeTabs

                if selectedTab == .daily {
                    dailyTabContent
                } else {
                    exploreTabContent
                }
            }
        }
    }
}

// MARK: - Header

private extension HoroscopeView {
    var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("planet")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(theme.palette.secondaryAccent)
                .bubblyIconMaterial(tint: theme.palette.secondaryAccent)

            Text("Daily Horoscope")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .bubblyIconMaterial(tint: theme.palette.secondaryAccent)

            Spacer()
        }
    }
}

// MARK: - Tabs

private extension HoroscopeView {
    var horoscopeTabs: some View {
        HStack(spacing: 10) {
            ForEach(HoroscopeTab.allCases) { tab in
                horoscopeTabButton(for: tab)
            }
        }
    }

    func horoscopeTabButton(for tab: HoroscopeTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            Text(tab.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isSelected
                            ? Color.white.opacity(0.14)
                            : Color.white.opacity(0.06)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected
                            ? Color.white.opacity(0.28)
                            : LColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily Tab

private extension HoroscopeView {
    @ViewBuilder
    var dailyTabContent: some View {
        if let horoscope = dailyHoroscope {
            horoscopeDisplay(horoscope)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose your zodiac sign once to lock in today’s horoscope.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                pickerField
                fetchButton(title: "Get Daily Horoscope")

                if let errorText {
                    errorTextView(errorText)
                }
            }
        }
    }
}

// MARK: - Explore Tab

private extension HoroscopeView {
    @ViewBuilder
    var exploreTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            pickerField
            fetchButton(title: "Preview Horoscope")

            if let horoscope = previewHoroscope {
                horoscopeDisplay(horoscope)

                Button {
                    onClearPreview()
                } label: {
                    Text("Clear")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if let errorText {
                errorTextView(errorText)
            }
        }
    }
}

// MARK: - Picker

private extension HoroscopeView {
    func zodiacAssetName(for sign: String) -> String {
        switch sign.lowercased() {
        case "aries": return "aries"
        case "taurus": return "taurus"
        case "gemini": return "gemini"
        case "cancer": return "cancer"
        case "leo": return "leo"
        case "virgo": return "virgo"
        case "libra": return "libra"
        case "scorpio": return "scorpio"
        case "sagittarius": return "sagittarius"
        case "capricorn": return "capricorn"
        case "aquarius": return "aquarius"
        case "pisces": return "pisces"
        default: return "aries"
        }
    }

    var pickerField: some View {
        Menu {
            ForEach(zodiacSigns, id: \.self) { sign in
                Button(sign) {
                    selectedSign = sign
                }
            }
        } label: {
            HStack(spacing: 10) {
                if !selectedSign.isEmpty {
                    Image(selectedZodiacAssetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                }

                Text(selectedSign.isEmpty ? "Select Zodiac Sign" : selectedSign.capitalized)

                Spacer()

                Image("chevdown")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Buttons

private extension HoroscopeView {
    func fetchButton(title: String) -> some View {
        Button {
            onFetch()
        } label: {
            HStack {
                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .background {
                BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                    .clipShape(Capsule())
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(selectedSign.isEmpty || isLoading)
    }
}

// MARK: - Horoscope Display

private extension HoroscopeView {
    func horoscopeDisplay(_ horoscope: DailyHoroscope) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(zodiacAssetName(for: horoscope.sign))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(theme.palette.secondaryAccent)
                    .bubblyIconMaterial(tint: theme.palette.secondaryAccent)

                Text(horoscope.sign.capitalized)

                Spacer()
            }

            Text(horoscope.message.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Error

private extension HoroscopeView {
    func errorTextView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.red.opacity(0.9))
    }
}

// MARK: - Horoscope Tab Enum

enum HoroscopeTab: String, CaseIterable, Identifiable {
    case daily
    case explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .explore:
            return "Explore"
        }
    }
}
