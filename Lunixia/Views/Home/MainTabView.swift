//
//  MainTabView.swift
//  Lunixia
//

import SwiftUI

enum LunixiaTab: CaseIterable {
    case mood
    case health
    case journal
    case profile
    case notes
    case spiritual
    case selfCarePoints
    case premium

    static let primaryTabs: [LunixiaTab] = [
        .mood,
        .health,
        .journal,
        .profile
    ]

    static let overflowTabs: [LunixiaTab] = [
        .notes,
        .spiritual,
        .selfCarePoints,
        .premium
    ]

    var icon: String {
        switch self {
        case .journal:
            return "lovejournal"

        case .mood:
            return "xsmile"

        case .health:
            return "healthy"

        case .profile:
            return "profilewavy"

        case .notes:
            return "pin"

        case .spiritual:
            return "sparkle"

        case .selfCarePoints:
            return "heartwavy"

        case .premium:
            return "lockwavy"
        }
    }

    var title: String {
        switch self {
        case .journal:
            return "Journal"

        case .mood:
            return "Mood"

        case .health:
            return "Health"

        case .profile:
            return "Profile"

        case .notes:
            return "Notes"

        case .spiritual:
            return "Spiritual"

        case .selfCarePoints:
            return "Self-Care Points"

        case .premium:
            return "Premium"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: LunixiaTab = .mood

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 4)
        }
        .background {
            LunixiaBackground()
                .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .journal:
            JournalTabView()

        case .mood:
            MoodTabView()

        case .health:
            HealthTabView()

        case .profile:
            NavigationStack {
                ProfileView()
            }

        case .notes:
            NotesView()

        case .spiritual:
            SpiritualView()

        case .selfCarePoints:
            SelfCarePointsView()

        case .premium:
            PremiumView()
        }
    }
}

// MARK: - Floating Tab Bar

    struct FloatingTabBar: View {
        @Binding var selectedTab: LunixiaTab

        @State private var showMoreTabs = false

        private var primaryTabs: [LunixiaTab] {
            LunixiaTab.primaryTabs
        }

        private var overflowTabs: [LunixiaTab] {
            LunixiaTab.overflowTabs
        }

        private var leadingTabs: [LunixiaTab] {
            Array(primaryTabs.prefix(2))
        }

        private var trailingTabs: [LunixiaTab] {
            Array(primaryTabs.dropFirst(2))
        }

        var body: some View {
            ZStack(alignment: .bottom) {
                if showMoreTabs && !overflowTabs.isEmpty {
                    moreTabsMenu
                        .padding(.bottom, 118)
                        .transition(.opacity)
                        .zIndex(1)
                }

                HStack(spacing: 10) {
                    ForEach(leadingTabs, id: \.self) { tab in
                        tabButton(tab)
                    }

                    centerAddButton

                    ForEach(trailingTabs, id: \.self) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background {
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(LColors.bg.opacity(0.88))

                        GlassCard(cornerRadius: 999, padding: 0) {
                            Color.clear
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 42)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: showMoreTabs)
        }

        private func tabButton(_ tab: LunixiaTab) -> some View {
            let isSelected = selectedTab == tab

            return Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    selectedTab = tab
                    showMoreTabs = false
                }
            } label: {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(LGradients.header.opacity(0.22))
                            .frame(width: 34, height: 34)
                    }

                    Image(tab.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(
                            isSelected
                            ? AnyShapeStyle(LGradients.header)
                            : AnyShapeStyle(Color.white.opacity(0.4))
                        )
                }
                .frame(width: 42, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        private var centerAddButton: some View {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    showMoreTabs.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(LGradients.header)
                        .frame(width: 44, height: 44)
                        .shadow(color: LColors.gradientBlue.opacity(0.35), radius: 10, x: 0, y: 5)

                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(LColors.bg)
                        .rotationEffect(.degrees(showMoreTabs ? 45 : 0))
                }
                .frame(width: 54, height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(overflowTabs.isEmpty)
            .opacity(overflowTabs.isEmpty ? 0.45 : 1)
        }

        private var moreTabsMenu: some View {
            CurvedDock(
                tabs: overflowTabs,
                selectedTab: $selectedTab,
                isExpanded: $showMoreTabs
            )
        }
    }

    // MARK: - Curved Dock

    private struct CurvedDock: View {

        let tabs: [LunixiaTab]
        @Binding var selectedTab: LunixiaTab
        @Binding var isExpanded: Bool

        @State private var revealedCount: Int = 0

        private let dockWidth: CGFloat = 200
        private let dockHeight: CGFloat = 78
        private let itemSize: CGFloat = 40
        private let arcHeight: CGFloat = 18

        var body: some View {
            ZStack {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    dockButton(tab)
                        .position(position(for: index))
                        .opacity(index < revealedCount ? 1 : 0)
                        .scaleEffect(index < revealedCount ? 1 : 0.5)
                        .animation(
                            .spring(response: 0.34, dampingFraction: 0.7),
                            value: revealedCount
                        )
                }
            }
            .frame(width: dockWidth, height: dockHeight)
            .onAppear { revealSequentially() }
            .onDisappear { revealedCount = 0 }
        }

        // MARK: - Reveal Animation

        private func revealSequentially() {
            revealedCount = 0
            for index in tabs.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.055) {
                    guard isExpanded else { return }
                    revealedCount = index + 1
                }
            }
        }

        // MARK: - Layout

        /// Horizontal inset shared by the arc path and the icon positions.
        private var arcInset: CGFloat { itemSize / 2 + 6 }

        /// Y coordinate of the arc's endpoints.
        private var arcBaseY: CGFloat { (dockHeight / 2) - (arcHeight / 2) }

        /// Point on the arc at normalized position `s` (0...1, left to right).
        private func pointOnArc(_ s: CGFloat) -> CGPoint {
            let x = arcInset + (dockWidth - arcInset * 2) * s
            let y = arcBaseY + 4 * arcHeight * s * (1 - s)
            return CGPoint(x: x, y: y)
        }

        /// Distributes the icons evenly along the arc.
        private func position(for index: Int) -> CGPoint {
            guard tabs.count > 1 else {
                return pointOnArc(0.5)
            }
            return pointOnArc(CGFloat(index) / CGFloat(tabs.count - 1))
        }

        // MARK: - Dock Button

        private func dockButton(_ tab: LunixiaTab) -> some View {
            let isSelected = selectedTab == tab

            return Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    selectedTab = tab
                    isExpanded = false
                }
            } label: {
                Image(tab.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 19, height: 19)
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(LGradients.header)
                        : AnyShapeStyle(LColors.textSecondary)
                    )
                    .frame(width: itemSize, height: itemSize)
                    .background {
                        Circle()
                            .fill(LColors.bg)
                            .overlay(
                                Circle()
                                    .fill(isSelected ? LColors.glassSurface2 : LColors.glassSurface)
                            )
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected
                                ? AnyShapeStyle(LGradients.header)
                                : AnyShapeStyle(LColors.glassBorder),
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
                    .shadow(
                        color: isSelected
                        ? LColors.gradientBlue.opacity(0.4)
                        : .black.opacity(0.25),
                        radius: isSelected ? 10 : 6,
                        y: 4
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

// MARK: - Placeholder Tab View

struct PlaceholderTabView: View {
    let icon: String
    let title: String

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(LGradients.blue)

                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Coming soon")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
