//
//  MedicationCardView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Medication Page View

struct MedicationPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \LunixiaMedication.createdAt, order: .forward) private var medications: [LunixiaMedication]

    @State private var showAddSheet       = false
    @State private var showEditSheet      = false
    @State private var showInventorySheet = false
    @State private var showHistorySheet   = false
    @State private var showRefillSheet    = false
    @State private var selectedMed: LunixiaMedication? = nil
    @State private var showDeleteConfirm  = false
    @State private var showBanner         = false
    @State private var bannerMessage      = ""

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var canCreateMedicationCard: Bool {
        LunixiaLimitsManager.canCreateMedicationCard(
            currentCount: medications.count,
            isPremium: isPremium
        )
    }

    private var upcomingRefillCount: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let sevenDays = cal.date(byAdding: .day, value: 7, to: today) else { return 0 }
        return medications.filter { med in
            guard let refill = med.refillDate else { return false }
            let refillDay = cal.startOfDay(for: refill)
            return refillDay >= today && refillDay <= sevenDays
        }.count
    }
    
    private var shouldUseFullScreenSheets: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Nav
                HStack(spacing: 16) {
                    Text("Medications")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                    }
                    .buttonStyle(.plain)
                    Button {
                        if canCreateMedicationCard {
                            showAddSheet = true
                        } else {
                            showPremiumRequiredMessage()
                        }
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(
                                canCreateMedicationCard
                                ? AnyShapeStyle(theme.palette.primaryAction)
                                : AnyShapeStyle(LColors.textSecondary.opacity(0.45))
                            )
                            .bubblyIconMaterial(
                                tint: theme.palette.primaryAction,
                                isEnabled: canCreateMedicationCard
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {

                        // MARK: Overview card
                        GlassCard(padding: 18) {
                            HStack(spacing: 14) {
                                overviewStat(
                                    label: "Medications",
                                    value: medications.count,
                                    tint: theme.palette.primaryAction
                                )
                                    .overlay {
                                        if !canCreateMedicationCard && !isPremium {
                                            LunixiaPremiumBlurOverlay(cornerRadius: 12)
                                        }
                                    }
                                Rectangle()
                                    .fill(LColors.glassBorder)
                                    .frame(width: 1)
                                    .padding(.vertical, 4)
                                overviewStat(
                                    label: "Refills (7 days)",
                                    value: upcomingRefillCount,
                                    tint: theme.palette.secondaryAccent
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        // MARK: Medication cards
                        if medications.isEmpty {
                            GlassCard(padding: 20) {
                                Text("no medications added yet")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.45))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(medications) { med in
                                GlassCard(padding: 0) {
                                    medicationRow(med)
                                        .padding(16)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .completionBanner(isShowing: showBanner, message: bannerMessage)
        .navigationBarHidden(true)
        .sheet(isPresented: Binding(
            get: { showAddSheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showAddSheet = false } }
        )) {
            MedAddEditSheet(mode: .add) { med in
                guard canCreateMedicationCard else {
                    showPremiumRequiredMessage()
                    return
                }
                if med.autoDecreaseEnabled && med.lastAutoDecreaseDayKey.isEmpty {
                    med.lastAutoDecreaseDayKey = MedicationAutomationManager.dayKey(for: Date())
                }
                
                modelContext.insert(med)
                guard saveMedicationChanges("add medication") else {
                    return
                }
                
                MedicationNotificationManager.shared.reschedule(for: med)
                
                flash("Medication added")
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { showAddSheet && shouldUseFullScreenSheets },
            set: { if !$0 { showAddSheet = false } }
        )) {
            MedAddEditSheet(mode: .add) { med in
                guard canCreateMedicationCard else {
                    showPremiumRequiredMessage()
                    return
                }
                if med.autoDecreaseEnabled && med.lastAutoDecreaseDayKey.isEmpty {
                    med.lastAutoDecreaseDayKey = MedicationAutomationManager.dayKey(for: Date())
                }

                modelContext.insert(med)
                guard saveMedicationChanges("add medication") else {
                    return
                }

                MedicationNotificationManager.shared.reschedule(for: med)

                flash("Medication added")
            }
        }
        .sheet(isPresented: Binding(
            get: { showEditSheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showEditSheet = false } }
        )) {
            if let med = selectedMed {
                MedAddEditSheet(mode: .edit(med)) { updated in
                    updated.updatedAt = Date()
                    updated.lastAutoRefillDayKey = ""

                    if updated.autoDecreaseEnabled &&
                        updated.lastAutoDecreaseDayKey.isEmpty {
                        updated.lastAutoDecreaseDayKey = MedicationAutomationManager.dayKey(for: Date())
                    }

                    guard saveMedicationChanges("edit medication") else {
                        return
                    }

                    MedicationNotificationManager.shared.reschedule(for: updated)

                    flash("Medication updated")
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { showEditSheet && shouldUseFullScreenSheets },
            set: { if !$0 { showEditSheet = false } }
        )) {
            if let med = selectedMed {
                MedAddEditSheet(mode: .edit(med)) { updated in
                    updated.updatedAt = Date()
                    updated.lastAutoRefillDayKey = ""

                    if updated.autoDecreaseEnabled &&
                        updated.lastAutoDecreaseDayKey.isEmpty {
                        updated.lastAutoDecreaseDayKey = MedicationAutomationManager.dayKey(for: Date())
                    }

                    guard saveMedicationChanges("edit medication") else {
                        return
                    }

                    MedicationNotificationManager.shared.reschedule(for: updated)

                    flash("Medication updated")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { showInventorySheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showInventorySheet = false } }
        )) {
            if let med = selectedMed {
                MedInventorySheet(medication: med) { action in
                    applyInventoryAction(action, to: med)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { showInventorySheet && shouldUseFullScreenSheets },
            set: { if !$0 { showInventorySheet = false } }
        )) {
            if let med = selectedMed {
                MedInventorySheet(medication: med) { action in
                    applyInventoryAction(action, to: med)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { showHistorySheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showHistorySheet = false } }
        )) {
            if let med = selectedMed {
                MedHistorySheet(medication: med, isPremium: isPremium) { entry in
                    modelContext.delete(entry)
                    _ = saveMedicationChanges("delete medication history entry")
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { showHistorySheet && shouldUseFullScreenSheets },
            set: { if !$0 { showHistorySheet = false } }
        )) {
            if let med = selectedMed {
                MedHistorySheet(medication: med, isPremium: isPremium) { entry in
                    modelContext.delete(entry)
                    _ = saveMedicationChanges("delete medication history entry")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { showRefillSheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showRefillSheet = false } }
        )) {
            if let med = selectedMed {
                MedDirectRefillSheet(medication: med) {
                    guard saveMedicationChanges("update refill date") else {
                        return
                    }
                    MedicationNotificationManager.shared.reschedule(for: med)
                    flash("Refill date updated")
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { showRefillSheet && shouldUseFullScreenSheets },
            set: { if !$0 { showRefillSheet = false } }
        )) {
            if let med = selectedMed {
                MedDirectRefillSheet(medication: med) {
                    guard saveMedicationChanges("update refill date") else {
                        return
                    }
                    MedicationNotificationManager.shared.reschedule(for: med)
                    flash("Refill date updated")
                }
            }
        }
        .lunixiaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete Medication",
            message: "Are you sure you want to delete this medication?",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let med = selectedMed {
                MedicationNotificationManager.shared.cancelAll(for: med)
                modelContext.delete(med)
                guard saveMedicationChanges("delete medication") else {
                    return
                }
                selectedMed = nil
                flash("Medication deleted")
            }
        }
        .task {
            LunixiaSyncIntegrityManager.shared.runPeriodicAutomationsIfSafe(
                container: LunixiaApp.sharedModelContainer
            )
            _ = await MedicationNotificationManager.shared.requestAuthorization()
        }
    }

    // MARK: - Overview Stat

    @ViewBuilder
    private func overviewStat(label: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .bubblyIconMaterial(tint: tint)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Medication Row

    @ViewBuilder
    private func medicationRow(_ med: LunixiaMedication) -> some View {
        let trimmedNotes = med.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let ringSize: CGFloat = 82
        let ringReserve: CGFloat = 98

        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(med.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(1)

                    if !trimmedNotes.isEmpty {
                        Text(trimmedNotes)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.72))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if let refill = med.refillDate {
                                medPill(
                                    text: "REFILL: \(shortRefillDate(refill))",
                                    tint: theme.palette.rotation[0]
                                )
                            }

                            if med.daysSupply > 0 {
                                let supplyIndex = med.refillDate == nil ? 0 : 1
                                medPill(
                                    text: "SUPPLY DAYS: \(med.daysSupply)",
                                    tint: theme.palette.rotation[supplyIndex]
                                )
                            }
                        }

                        if med.notifyDose || med.autoDecreaseEnabled {
                            HStack(spacing: 6) {
                                let firstRowCount = (med.refillDate == nil ? 0 : 1) + (med.daysSupply > 0 ? 1 : 0)

                                if med.notifyDose {
                                    medPill(
                                        text: "ALERTS: Enabled",
                                        tint: theme.palette.rotation[firstRowCount % theme.palette.rotation.count]
                                    )
                                }

                                if med.autoDecreaseEnabled {
                                    let autoIndex = firstRowCount + (med.notifyDose ? 1 : 0)
                                    medPill(
                                        text: "AUTO",
                                        tint: theme.palette.rotation[autoIndex % theme.palette.rotation.count]
                                    )
                                }

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.trailing, ringReserve)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: ringSize, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)

                medicationDottedProgressRing(med)
                    .frame(width: ringSize, height: ringSize)
            }

            HStack(spacing: 8) {
                Button { takeDose(med) } label: {
                    HStack(spacing: 5) {
                        Image("checkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)

                        Text("Log Dose")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        BubblyIconMaterial(tint: theme.palette.primaryAction)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .disabled(med.currentAmount == 0)

                Spacer()

                rowIconButton(asset: "dotswavy") { selectedMed = med; showInventorySheet = true }
                rowIconButton(asset: "clockfill") { selectedMed = med; showHistorySheet = true }
                rowIconButton(asset: "lovecalendar") { selectedMed = med; showRefillSheet = true }
                rowIconButton(asset: "pencil") { selectedMed = med; showEditSheet = true }
                rowIconButton(asset: "trash", tint: theme.palette.secondaryAccent) { selectedMed = med; showDeleteConfirm = true }
            }
        }
    }
    
    private func medicationPillCount(for med: LunixiaMedication) -> Int {
        var count = 0
        if med.refillDate != nil { count += 1 }
        if med.daysSupply > 0 { count += 1 }
        if med.notifyDose { count += 1 }
        if med.autoDecreaseEnabled { count += 1 }
        return count
    }

    // MARK: - Helpers

    private func supplyProgress(_ med: LunixiaMedication) -> CGFloat {
        guard med.supplyAmount > 0 else { return 0 }
        return min(max(CGFloat(med.currentAmount) / CGFloat(med.supplyAmount), 0), 1)
    }

    private func shortRefillDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }

    private func medicationDottedProgressRing(_ med: LunixiaMedication) -> some View {
        let dotCount = 36
        let progress = supplyProgress(med)
        let filledDots = Int((progress * CGFloat(dotCount)).rounded())
        let size: CGFloat = 82
        let dotSize: CGFloat = 6.5
        let radius: CGFloat = 34

        return ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let angle = (Double(index) / Double(dotCount)) * 360.0 - 90.0
                let isFilled = index < filledDots
                let dotTint = isFilled
                    ? theme.palette.rotation[index % theme.palette.rotation.count]
                    : LColors.glassBorder.opacity(0.45)

                BubblyIconMaterial(tint: dotTint)
                    .frame(width: dotSize, height: dotSize)
                    .clipShape(Circle())
                    .offset(
                        x: CGFloat(cos(angle * .pi / 180.0)) * radius,
                        y: CGFloat(sin(angle * .pi / 180.0)) * radius
                    )
            }

            VStack(spacing: 2) {
                Text("\(med.currentAmount)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Rectangle()
                    .fill(LColors.glassBorder.opacity(0.75))
                    .frame(width: 22, height: 1)
                Text("\(med.supplyAmount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Medication supply")
        .accessibilityValue("\(med.currentAmount) out of \(med.supplyAmount)")
    }

    @ViewBuilder
    private func medPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                BubblyIconMaterial(tint: tint)
                    .clipShape(Capsule())
            }
    }

    @ViewBuilder
    private func rowIconButton(asset: String, tint: Color = LColors.textSecondary.opacity(0.7), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(tint)
                .bubblyIconMaterial(tint: tint)
                .frame(width: 30, height: 30)
                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Take Dose

    private func takeDose(_ med: LunixiaMedication) {
        let doses = med.dosesToday
        guard doses > 0 else {
            flash("No dose scheduled for \(med.name) today")
            return
        }
        let now = Date()
        let todayKey = MedicationAutomationManager.dayKey(for: now)
        let previous = med.currentAmount
        let newAmount = max(0, med.currentAmount - doses)
        med.currentAmount = newAmount
        med.lastTakenAt = now
        med.updatedAt = now

        if med.autoDecreaseEnabled {
            med.lastAutoDecreaseDayKey = todayKey
        }
        modelContext.insert(LunixiaMedHistoryEntry(
            type: .taken,
            amountText: "\(previous) → \(newAmount)",
            details: doses > 1 ? "\(doses) doses marked as taken" : "Dose marked as taken",
            effectiveDayKey: todayKey,
            medication: med
        ))
        guard saveMedicationChanges("take medication dose") else {
            return
        }
        let dk = LunixiaPointsManager.dayKey()
        _ = try? LunixiaPointsManager.awardMedicationTaken(in: modelContext, medId: med.id.uuidString, dayKey: dk)
        flash(doses > 1 ? "\(doses) doses taken for \(med.name)" : "Dose taken for \(med.name)")
    }

    // MARK: - Inventory

    private func applyInventoryAction(_ action: InventoryAction, to med: LunixiaMedication) {
        let now = Date()
        let todayKey = MedicationAutomationManager.dayKey(for: now)
        let previous = med.currentAmount
        switch action {
        case .adjust(let delta): med.currentAmount = max(0, med.currentAmount + delta)
        case .setFull:           med.currentAmount = max(0, med.supplyAmount)
        }

        if med.autoDecreaseEnabled {
            med.lastAutoDecreaseDayKey = todayKey
        }

        med.updatedAt = now
        let details: String
        switch action {
        case .adjust(let d): details = d >= 0 ? "Manual inventory increase" : "Manual inventory decrease"
        case .setFull:       details = "Set inventory to full supply"
        }
        modelContext.insert(LunixiaMedHistoryEntry(
            type: .edited,
            amountText: "\(previous) → \(med.currentAmount)",
            details: details,
            effectiveDayKey: todayKey,
            medication: med
        ))
        _ = saveMedicationChanges("edit medication inventory")
    }

    // MARK: - Banner

    @discardableResult
    private func saveMedicationChanges(_ context: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            print("[MedicationPageView] Failed to \(context): \(error)")
            flash("Medication changes could not be saved")
            return false
        }
    }

    private func showPremiumRequiredMessage() {
        flash("Premium unlocks more medication cards.")
    }

    private func flash(_ message: String) {
        bannerMessage = message
        withAnimation { showBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { showBanner = false } }
    }
}

// MARK: - Inventory Action

enum InventoryAction { case adjust(Int); case setFull }

// ============================================================
// MARK: - Medication Pill Wrap Layout
// ============================================================

private struct MedPillWrap: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6
    var fallbackWidth: CGFloat = 260

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let proposedWidth = proposal.width ?? fallbackWidth
        let maxWidth = proposedWidth.isFinite ? proposedWidth : fallbackWidth
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsNewRow = currentX > 0 && currentX + spacing + size.width > maxWidth

            if needsNewRow {
                widestRow = max(widestRow, currentX)
                totalHeight += currentRowHeight + rowSpacing
                currentX = 0
                currentRowHeight = 0
            }

            if currentX > 0 {
                currentX += spacing
            }

            currentX += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }

        widestRow = max(widestRow, currentX)
        totalHeight += currentRowHeight

        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxX = bounds.maxX
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsNewRow = currentX > bounds.minX && currentX + spacing + size.width > maxX

            if needsNewRow {
                currentX = bounds.minX
                currentY += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

// ============================================================
// MARK: - Medication Material Controls
// ============================================================

private struct MedicationSlidingIconToggle: View {
    @Environment(\.appTheme) private var theme

    @Binding var isOn: Bool
    let iconName: String
    let accentColor: Color
    let accessibilityLabel: String
    var isDisabled = false
    var usesIconMaterial = true
    var width: CGFloat = 58
    var height: CGFloat = 32

    private var knobSize: CGFloat { max(24, height - 6) }

    var body: some View {
        Button {
            guard !isDisabled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? accentColor.opacity(0.24) : Color.white.opacity(0.07))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isOn ? accentColor.opacity(0.58) : Color.white.opacity(0.16),
                                lineWidth: 1
                            )
                    }

                HStack {
                    if isOn { Spacer(minLength: 0) }

                    ZStack {
                        if isOn && usesIconMaterial {
                            BubblyIconMaterial(tint: accentColor)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(isOn ? accentColor : theme.palette.raisedSurface)
                        }

                        Circle()
                            .strokeBorder(Color.white.opacity(isOn ? 0.16 : 0.12), lineWidth: 1)

                        Image(iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(isOn ? Color.black : theme.palette.textSecondary)
                    }
                    .frame(width: knobSize, height: knobSize)

                    if !isOn { Spacer(minLength: 0) }
                }
                .padding(3)
            }
            .frame(width: width, height: height)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct MedicationRefillControls: View {
    @Environment(\.appTheme) private var theme

    @Binding var hasRefillDate: Bool
    @Binding var refillDate: Date

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set a refill date")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Text("Auto-refills supply and advances the date when due.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    MedicationSlidingIconToggle(
                        isOn: $hasRefillDate,
                        iconName: "checkwavy",
                        accentColor: theme.palette.primaryAction,
                        accessibilityLabel: "Set a refill date"
                    )
                }

                if hasRefillDate {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionKicker("refill date")
                        MedicationRefillCalendar(selection: $refillDate)
                    }
                }
            }
        }
    }
}

private struct MedicationRefillCalendar: View {
    @Environment(\.appTheme) private var theme

    @Binding var selection: Date
    @State private var displayedMonth: Date
    @State private var showsMonthSelector = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    init(selection: Binding<Date>) {
        _selection = selection
        let initial = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: selection.wrappedValue)
        ) ?? selection.wrappedValue
        _displayedMonth = State(initialValue: initial)
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        calendar.shortStandaloneWeekdaySymbols.map { String($0.prefix(3)).uppercased() }
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let monthDays: [Date?] = range.map { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        return Array(repeating: nil, count: leading) + monthDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        showsMonthSelector.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(monthTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)

                        Image(showsMonthSelector ? "downwavy" : "rightwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                monthStepButton(asset: "leftwavy", value: -1)
                monthStepButton(asset: "rightwavy", value: 1)
            }

            if showsMonthSelector {
                monthSelector
            } else {
                dayGrid
            }
        }
        .onChange(of: selection) { _, newValue in
            guard !calendar.isDate(newValue, equalTo: displayedMonth, toGranularity: .month) else { return }
            displayedMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: newValue)
            ) ?? newValue
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayButton(date)
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private var monthSelector: some View {
        LazyVGrid(columns: monthColumns, spacing: 8) {
            ForEach(1...12, id: \.self) { month in
                let isSelected = calendar.component(.month, from: monthStart) == month
                Button {
                    var components = calendar.dateComponents([.year], from: monthStart)
                    components.month = month
                    components.day = 1
                    if let date = calendar.date(from: components) {
                        displayedMonth = date
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        showsMonthSelector = false
                    }
                } label: {
                    Text(calendar.shortMonthSymbols[month - 1])
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : LColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                BubblyIconMaterial(tint: theme.palette.primaryAction)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(theme.palette.raisedSurface)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)

        return Button {
            selection = date
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected ? .black : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if isSelected {
                        BubblyIconMaterial(tint: theme.palette.indicators)
                            .clipShape(Circle())
                    } else if isToday {
                        Circle()
                            .strokeBorder(theme.palette.primaryAction, lineWidth: 1.2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .long, time: .omitted))
    }

    private func monthStepButton(asset: String, value: Int) -> some View {
        Button {
            let component: Calendar.Component = showsMonthSelector ? .year : .month
            displayedMonth = calendar.date(byAdding: component, value: value, to: monthStart) ?? monthStart
        } label: {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(theme.palette.secondaryAccent)
                .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - Add / Edit Sheet
// ============================================================

struct MedAddEditSheet: View {
    enum Mode { case add; case edit(LunixiaMedication) }

    let mode: Mode
    let onSave: (LunixiaMedication) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @FocusState private var focusedInput: MedicationInputField?

    @State private var name          = ""
    @State private var notes         = ""
    @State private var currentAmount = ""
    @State private var supplyAmount  = ""
    @State private var daysSupply    = ""
    @State private var includeRefillDate = false
    @State private var refillDate        = Date()
    @State private var scheduleFrequency: LunixiaMedication.LunixiaMedicationScheduleFrequency = .daily
    @State private var weeklyWeekday     = Calendar.current.component(.weekday, from: Date())
    @State private var defaultDoses      = 1
    @State private var doseOverrides: [Int: Int] = [:]
    @State private var autoDecreaseEnabled = false
    @State private var autoDecreaseHour    = 9
    @State private var autoDecreaseMinute  = 0
    @State private var notifyDose          = false
    @State private var doseNotifyTimes: [DoseNotifyTime] = [DoseNotifyTime(hour: 9, minute: 0)]
    @State private var notifyRefill      = false
    @State private var daysBeforeRefill  = 3
    @State private var didLoadInitialValues = false

    @State private var showRefillSheet   = false
    @State private var showScheduleSheet = false
    @State private var showNotifySheet   = false

    private var isAdd: Bool { if case .add = mode { return true }; return false }
    
    private enum MedicationInputField: Hashable {
        case name
        case notes
        case currentAmount
        case supplyAmount
        case daysSupply
    }

    private var refillSummary: String {
        guard includeRefillDate else { return "not set" }
        return refillDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var scheduleSummary: String {
        switch scheduleFrequency {
        case .daily:
            if doseOverrides.isEmpty { return "\(defaultDoses)x daily" }
            let allSet = doseOverrides.count == 7
            if allSet { return "custom per day" }
            return "\(defaultDoses)x default · \(doseOverrides.count) custom"
        case .weekly:
            return "\(defaultDoses)x every \(weekdayShortName(weeklyWeekday))"
        }
    }

    private var notifySummary: String {
        var parts: [String] = []
        if notifyDose {
            let times = doseNotifyTimes.map { $0.displayString }
            parts.append(times.joined(separator: ", "))
        }
        if notifyRefill { parts.append("refill \(daysBeforeRefill)d before") }
        return parts.isEmpty ? "off" : parts.joined(separator: " · ")
    }
    
    private var shouldUseFullScreenSheets: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    HStack {
                        Text(isAdd ? "Add Medication" : "Edit Medication")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Spacer()
                        Button { dismiss() } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(theme.palette.primaryAction)
                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                        }
                        .buttonStyle(.plain)
                    }

                    // ── Details ───────────────────────────────────────────
                    fieldSection(label: "details") {
                        groupedField(label: "Name",           text: $name,          keyboard: .default,   position: .top)
                        groupedDivider()
                        groupedField(label: "Current Amount", text: $currentAmount, keyboard: .numberPad, position: .middle)
                        groupedDivider()
                        groupedField(label: "Supply Amount",  text: $supplyAmount,  keyboard: .numberPad, position: .middle)
                        groupedDivider()
                        groupedField(label: "Days Supply",    text: $daysSupply,    keyboard: .numberPad, position: .bottom)
                    }

                    // ── Notes ─────────────────────────────────────────────
                    notesSection

                    // ── Configuration ─────────────────────────────────────
                    fieldSection(label: "configuration") {
                        configRow(asset: "lovecalendar", label: "Refill Date", summary: refillSummary, position: .top, tint: theme.palette.primaryAction) { showRefillSheet = true }
                        groupedDivider()
                        configRow(asset: "pilldrop", label: "Dose Schedule", summary: scheduleSummary, position: .middle, tint: theme.palette.secondaryAccent) { showScheduleSheet = true }
                        groupedDivider()
                        configRow(asset: "bellfill", label: "Notifications", summary: notifySummary, position: .bottom, tint: theme.palette.indicators) { showNotifySheet = true }
                    }

                    // ── Auto Decrease ──────────────────────────────────────
                    autoDecreaseSection

                    medSaveButton(label: "Save Medication", tint: theme.palette.indicators) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedInput = nil
                        }
                )
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    focusedInput = nil
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(LGradients.header, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { loadIfEditing() }
        .sheet(isPresented: Binding(
            get: { showRefillSheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showRefillSheet = false } }
        )) {
            MedRefillConfigSheet(includeRefillDate: $includeRefillDate, refillDate: $refillDate)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showRefillSheet && shouldUseFullScreenSheets },
            set: { if !$0 { showRefillSheet = false } }
        )) {
            MedRefillConfigSheet(includeRefillDate: $includeRefillDate, refillDate: $refillDate)
        }
        .sheet(isPresented: Binding(
            get: { showScheduleSheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showScheduleSheet = false } }
        )) {
            MedScheduleConfigSheet(
                scheduleFrequency: $scheduleFrequency,
                weeklyWeekday: $weeklyWeekday,
                defaultDoses: $defaultDoses,
                doseOverrides: $doseOverrides
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { showScheduleSheet && shouldUseFullScreenSheets },
            set: { if !$0 { showScheduleSheet = false } }
        )) {
            MedScheduleConfigSheet(
                scheduleFrequency: $scheduleFrequency,
                weeklyWeekday: $weeklyWeekday,
                defaultDoses: $defaultDoses,
                doseOverrides: $doseOverrides
            )
        }
        .sheet(isPresented: Binding(
            get: { showNotifySheet && !shouldUseFullScreenSheets },
            set: { if !$0 { showNotifySheet = false } }
        )) {
            MedNotifyConfigSheet(
                notifyDose: $notifyDose,
                doseNotifyTimes: $doseNotifyTimes,
                notifyRefill: $notifyRefill,
                daysBeforeRefill: $daysBeforeRefill
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { showNotifySheet && shouldUseFullScreenSheets },
            set: { if !$0 { showNotifySheet = false } }
        )) {
            MedNotifyConfigSheet(
                notifyDose: $notifyDose,
                doseNotifyTimes: $doseNotifyTimes,
                notifyRefill: $notifyRefill,
                daysBeforeRefill: $daysBeforeRefill
            )
        }
    }

    // MARK: - Layout helpers

    enum RowPosition { case top, middle, bottom }

    private func corners(for position: RowPosition) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        switch position {
        case .top:    return (14, 14, 0, 0)
        case .middle: return (0, 0, 0, 0)
        case .bottom: return (0, 0, 14, 14)
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionKicker(label)
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    @ViewBuilder
    private func groupedDivider() -> some View {
        Rectangle()
            .fill(LColors.glassBorder)
            .frame(height: 0.75)
            .padding(.leading, 16)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionKicker("notes")
            GlassCard(padding: 0) {
                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .foregroundStyle(LColors.textPrimary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .focused($focusedInput, equals: .notes)
                    .frame(minHeight: 96)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.clear)
                    .overlay(alignment: .topLeading) {
                        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Optional notes...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.45))
                                .padding(.horizontal, 17)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func groupedField(label: String, text: Binding<String>, keyboard: UIKeyboardType, position: RowPosition) -> some View {
        let c = corners(for: position)
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .frame(width: 130, alignment: .leading)
            TextField("", text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .words : .never)
                .autocorrectionDisabled(keyboard != .default)
                .foregroundStyle(LColors.textPrimary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .multilineTextAlignment(.trailing)
                .focused($focusedInput, equals: inputField(for: label))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: c.0, bottomLeadingRadius: c.2, bottomTrailingRadius: c.3, topTrailingRadius: c.1)
                .fill(Color.clear)
        )
    }

    private func inputField(for label: String) -> MedicationInputField? {
        switch label {
        case "Name": return .name
        case "Current Amount": return .currentAmount
        case "Supply Amount": return .supplyAmount
        case "Days Supply": return .daysSupply
        default: return nil
        }
    }

    @ViewBuilder
    private func configRow(
        asset: String,
        label: String,
        summary: String,
        position: RowPosition,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        let c = corners(for: position)
        Button(action: action) {
            HStack(spacing: 12) {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(tint)
                    .bubblyIconMaterial(tint: tint)
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Spacer()
                Text(summary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(1)
                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(LColors.textSecondary.opacity(0.45))
                    .bubblyIconMaterial(tint: LColors.textSecondary.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: c.0, bottomLeadingRadius: c.2, bottomTrailingRadius: c.3, topTrailingRadius: c.1)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var autoDecreaseTimeDisplayString: String {
        let cleanHour = min(max(autoDecreaseHour, 0), 23)
        let cleanMinute = min(max(autoDecreaseMinute, 0), 59)

        let hour = cleanHour % 12 == 0 ? 12 : cleanHour % 12
        let minute = String(format: "%02d", cleanMinute)
        let period = cleanHour < 12 ? "AM" : "PM"

        return "\(hour):\(minute) \(period)"
    }

    private var autoDecreaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionKicker("auto decrease")

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Auto Decrease")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)

                            Text("Automatically subtract the scheduled dose amount once per day.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        MedicationSlidingIconToggle(
                            isOn: $autoDecreaseEnabled,
                            iconName: "checkwavy",
                            accentColor: theme.palette.primaryAction,
                            accessibilityLabel: "Auto Decrease",
                            usesIconMaterial: true
                        )
                    }

                    if autoDecreaseEnabled {
                        Divider()
                            .overlay(LColors.glassBorder)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Decrease Time")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(theme.palette.secondaryAccent)
                                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)

                                    Text("Inventory updates at this time or the next time Lunixia becomes active afterward.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Text(autoDecreaseTimeDisplayString)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.palette.secondaryAccent)
                                    .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            }

                            LunixiaGradientTimeDrumPicker(
                                hour: $autoDecreaseHour,
                                minute: $autoDecreaseMinute,
                                tint: theme.palette.secondaryAccent
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true
        guard case .edit(let med) = mode else { return }
        name          = med.name
        notes         = med.notes
        currentAmount = String(med.currentAmount)
        supplyAmount  = String(med.supplyAmount)
        daysSupply    = med.daysSupply > 0 ? String(med.daysSupply) : ""
        if let rd = med.refillDate { includeRefillDate = true; refillDate = rd }
        scheduleFrequency = med.scheduleFrequency
        weeklyWeekday = med.weeklyWeekday
        defaultDoses    = med.timesPerDay
        doseOverrides   = med.doseScheduleOverrides
        autoDecreaseEnabled = med.autoDecreaseEnabled
        autoDecreaseHour = med.autoDecreaseHour
        autoDecreaseMinute = med.autoDecreaseMinute
        notifyDose = med.notifyDose
        doseNotifyTimes = med.doseNotifyTimes
        notifyRefill    = med.notifyRefill
        daysBeforeRefill = med.daysBeforeRefillNotify
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let current = Int(currentAmount) ?? 0
        let supply  = Int(supplyAmount) ?? 0
        let days    = Int(daysSupply) ?? 0

        switch mode {
        case .add:
            onSave(LunixiaMedication(
                name: trimmedName, notes: trimmedNotes, currentAmount: current, supplyAmount: supply,
                daysSupply: days, refillDate: includeRefillDate ? refillDate : nil,
                scheduleFrequency: scheduleFrequency,
                weeklyWeekday: weeklyWeekday,
                timesPerDay: defaultDoses,
                doseScheduleOverrides: doseOverrides,
                autoDecreaseEnabled: autoDecreaseEnabled,
                autoDecreaseHour: autoDecreaseHour,
                autoDecreaseMinute: autoDecreaseMinute,
                notifyDose: notifyDose,
                doseNotifyTimes: doseNotifyTimes,
                notifyRefill: notifyRefill, daysBeforeRefillNotify: daysBeforeRefill
            ))
        case .edit(let med):
            let previousCurrentAmount = med.currentAmount
            let previousSupplyAmount = med.supplyAmount
            let previousDaysSupply = med.daysSupply
            let previousRefillDate = med.refillDate
            let previousFrequency = med.scheduleFrequency
            let previousWeeklyWeekday = med.weeklyWeekday
            let previousTimesPerDay = med.timesPerDay
            let previousDoseOverrides = med.doseScheduleOverrides
            let now = Date()
            let todayKey = MedicationAutomationManager.dayKey(for: now)

            med.name = trimmedName; med.notes = trimmedNotes; med.currentAmount = current
            med.supplyAmount = supply; med.daysSupply = days
            med.refillDate = includeRefillDate ? refillDate : nil
            med.scheduleFrequency = scheduleFrequency
            med.weeklyWeekday = min(max(weeklyWeekday, 1), 7)
            med.timesPerDay = defaultDoses; med.doseScheduleOverrides = scheduleFrequency == .weekly ? [:] : doseOverrides
            med.autoDecreaseEnabled = autoDecreaseEnabled
            med.autoDecreaseHour = min(max(autoDecreaseHour, 0), 23)
            med.autoDecreaseMinute = min(max(autoDecreaseMinute, 0), 59)

            if !autoDecreaseEnabled {
                med.lastAutoDecreaseDayKey = ""
            } else {
                med.lastAutoDecreaseDayKey = todayKey
            }

            med.notifyDose = notifyDose
            med.doseNotifyTimes = doseNotifyTimes
            med.notifyRefill = notifyRefill; med.daysBeforeRefillNotify = daysBeforeRefill

            insertManualEditHistoryIfNeeded(
                for: med,
                previousCurrentAmount: previousCurrentAmount,
                previousSupplyAmount: previousSupplyAmount,
                previousDaysSupply: previousDaysSupply,
                previousRefillDate: previousRefillDate,
                previousFrequency: previousFrequency,
                previousWeeklyWeekday: previousWeeklyWeekday,
                previousTimesPerDay: previousTimesPerDay,
                previousDoseOverrides: previousDoseOverrides,
                currentAmount: current,
                supplyAmount: supply,
                daysSupply: days,
                refillDate: med.refillDate,
                scheduleFrequency: med.scheduleFrequency,
                weeklyWeekday: med.weeklyWeekday,
                timesPerDay: med.timesPerDay,
                doseOverrides: med.doseScheduleOverrides,
                effectiveDayKey: todayKey,
                now: now
            )
            onSave(med)
        }
        dismiss()
    }

    private func insertManualEditHistoryIfNeeded(
        for medication: LunixiaMedication,
        previousCurrentAmount: Int,
        previousSupplyAmount: Int,
        previousDaysSupply: Int,
        previousRefillDate: Date?,
        previousFrequency: LunixiaMedication.LunixiaMedicationScheduleFrequency,
        previousWeeklyWeekday: Int,
        previousTimesPerDay: Int,
        previousDoseOverrides: [Int: Int],
        currentAmount: Int,
        supplyAmount: Int,
        daysSupply: Int,
        refillDate: Date?,
        scheduleFrequency: LunixiaMedication.LunixiaMedicationScheduleFrequency,
        weeklyWeekday: Int,
        timesPerDay: Int,
        doseOverrides: [Int: Int],
        effectiveDayKey: String,
        now: Date
    ) {
        var changes: [String] = []

        if previousCurrentAmount != currentAmount {
            changes.append("current amount")
        }

        if previousSupplyAmount != supplyAmount {
            changes.append("supply amount")
        }

        if previousDaysSupply != daysSupply {
            changes.append("days supply")
        }

        if !sameRefillDay(previousRefillDate, refillDate) {
            changes.append("refill date")
        }

        if previousFrequency != scheduleFrequency ||
            previousWeeklyWeekday != weeklyWeekday ||
            previousTimesPerDay != timesPerDay ||
            previousDoseOverrides != doseOverrides {
            changes.append("dose schedule")
        }

        guard !changes.isEmpty else {
            return
        }

        modelContext.insert(
            LunixiaMedHistoryEntry(
                type: .edited,
                amountText: "\(previousCurrentAmount) → \(currentAmount)",
                details: "Manual edit: \(changes.joined(separator: ", ")).",
                effectiveDayKey: effectiveDayKey,
                createdAt: now,
                medication: medication
            )
        )
    }

    private func sameRefillDay(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return Calendar.current.isDate(lhs, inSameDayAs: rhs)
        default:
            return false
        }
    }
    
    private func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "Sun"
        }
    }
}

// ============================================================
// MARK: - Refill Config Sub-Sheet
// ============================================================

struct MedRefillConfigSheet: View {
    @Binding var includeRefillDate: Bool
    @Binding var refillDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {

                HStack {
                    Text("Refill Date")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                    .buttonStyle(.plain)
                }

                MedicationRefillControls(
                    hasRefillDate: $includeRefillDate,
                    refillDate: $refillDate
                )

                Spacer()
                medDoneButton(
                    label: "Save Refill Date",
                    tint: theme.palette.primaryAction
                ) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }
}

// ============================================================
// MARK: - Schedule Config Sub-Sheet
// ============================================================

struct MedScheduleConfigSheet: View {
    @Binding var scheduleFrequency: LunixiaMedication.LunixiaMedicationScheduleFrequency
    @Binding var weeklyWeekday: Int
    @Binding var defaultDoses: Int
    @Binding var doseOverrides: [Int: Int]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    private let days: [(label: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7),
    ]

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    medSheetHeader(
                        title: "Dose Schedule",
                        tint: theme.palette.primaryAction
                    ) { dismiss() }

                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose whether this medication is taken daily or once weekly, then set the dose amount.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)

                            scheduleFrequencyPicker

                            Divider().overlay(LColors.glassBorder)

                            if scheduleFrequency == .weekly {
                                weeklyScheduleSection
                            } else {
                                dailyScheduleSection
                            }
                        }
                    }

                    Spacer(minLength: 20)
                    medDoneButton(tint: theme.palette.primaryAction) { dismiss() }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .onChange(of: scheduleFrequency) { _, newValue in
            if newValue == .weekly {
                doseOverrides = [:]
                weeklyWeekday = min(max(weeklyWeekday, 1), 7)
            }
        }
    }

    private var scheduleFrequencyPicker: some View {
        HStack(spacing: 10) {
            frequencyButton(title: "Daily", isSelected: scheduleFrequency == .daily) {
                withAnimation { scheduleFrequency = .daily }
            }
            frequencyButton(title: "Weekly", isSelected: scheduleFrequency == .weekly) {
                withAnimation { scheduleFrequency = .weekly }
            }
        }
    }

    private func frequencyButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let tint = title == "Daily"
            ? theme.palette.primaryAction
            : theme.palette.secondaryAccent

        return Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    BubblyCardMaterial(tint: tint, cornerRadius: 11)
                        .opacity(isSelected ? 1 : 0.48)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isSelected ? tint : LColors.glassBorder, lineWidth: isSelected ? 1.2 : 0.85)
                )
        }
        .buttonStyle(.plain)
    }

    private var dailyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set how many doses to take each day. Tap a day bubble to set a custom amount — when all days have custom values, the default no longer applies.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            MedDoseScheduleGrid(defaultQuantity: $defaultDoses, overrides: $doseOverrides)
        }
    }

    private var weeklyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                sectionKicker("weekly day")
                HStack(spacing: 6) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        let isSelected = weeklyWeekday == day.weekday
                        let tint = theme.palette.rotation[index % theme.palette.rotation.count]
                        Button {
                            weeklyWeekday = day.weekday
                        } label: {
                            Text(day.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background {
                                    BubblyIconMaterial(tint: tint)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .opacity(isSelected ? 1 : 0.38)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? tint : LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Dose")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                    Text("How many doses are taken on the selected day.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if defaultDoses > 1 { defaultDoses -= 1 }
                    } label: {
                        Image("chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(defaultDoses <= 1)

                    Text("\(defaultDoses)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(minWidth: 30, alignment: .center)

                    Button {
                        if defaultDoses < 99 { defaultDoses += 1 }
                    } label: {
                        Image("chevup")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Auto Decrease and Log Dose will only subtract on the selected weekly day.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.5))
        }
    }
}

// ============================================================
// MARK: - Notifications Config Sub-Sheet
// ============================================================

struct MedNotifyConfigSheet: View {
    @Binding var notifyDose: Bool
    @Binding var doseNotifyTimes: [DoseNotifyTime]
    @Binding var notifyRefill: Bool
    @Binding var daysBeforeRefill: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    medSheetHeader(
                        title: "Notifications",
                        tint: theme.palette.primaryAction
                    ) { dismiss() }

                    // ── Dose reminders ────────────────────────────────────
                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Dose reminders")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    Text("Get notified at each time you add below.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                }

                                Spacer(minLength: 12)

                                MedicationSlidingIconToggle(
                                    isOn: $notifyDose,
                                    iconName: "bellfill",
                                    accentColor: theme.palette.secondaryAccent,
                                    accessibilityLabel: "Dose reminders"
                                )
                            }

                            if notifyDose {
                                VStack(alignment: .leading, spacing: 12) {
                                    doseReminderPickers

                                    Button {
                                        withAnimation {
                                            doseNotifyTimes.append(DoseNotifyTime(hour: 9, minute: 0))
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image("addwavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                                .foregroundStyle(theme.palette.primaryAction)
                                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                                            Text("Add reminder time")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(theme.palette.primaryAction)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(LColors.glassSurface)
                                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // ── Refill reminder ───────────────────────────────────
                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Refill reminder")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    Text("Get notified a few days before your refill date.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                }

                                Spacer(minLength: 12)

                                MedicationSlidingIconToggle(
                                    isOn: $notifyRefill,
                                    iconName: "lovecalendar",
                                    accentColor: theme.palette.indicators,
                                    accessibilityLabel: "Refill reminder"
                                )
                            }

                            if notifyRefill {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionKicker("days before refill")
                                    HStack(spacing: 16) {
                                        Button {
                                            if daysBeforeRefill > 1 { daysBeforeRefill -= 1 }
                                        } label: {
                                            Image("chevdown")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(theme.palette.primaryAction)
                                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                                                .frame(width: 44, height: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(daysBeforeRefill <= 1)

                                        Text("\(daysBeforeRefill) day\(daysBeforeRefill == 1 ? "" : "s")")
                                            .font(.system(size: 18, weight: .black, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                            .frame(minWidth: 80, alignment: .center)

                                        Button {
                                            if daysBeforeRefill < 30 { daysBeforeRefill += 1 }
                                        } label: {
                                            Image("chevup")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(theme.palette.primaryAction)
                                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                                                .frame(width: 44, height: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                    medDoneButton(tint: theme.palette.secondaryAccent) { dismiss() }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }

    @ViewBuilder
    private var doseReminderPickers: some View {
        if doseNotifyTimes.count <= 1 {
            ForEach($doseNotifyTimes) { $time in
                reminderTimePicker(time: $time, compact: false)
            }
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach($doseNotifyTimes) { $time in
                    reminderTimePicker(time: $time, compact: true)
                }
            }
        }
    }

    private func reminderTimePicker(
        time: Binding<DoseNotifyTime>,
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(time.wrappedValue.displayString)
                    .font(.system(size: compact ? 11 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)

                Spacer(minLength: 6)

                if doseNotifyTimes.count > 1 {
                    Button {
                        withAnimation {
                            doseNotifyTimes.removeAll { $0.id == time.wrappedValue.id }
                        }
                    } label: {
                        Image("trash")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if compact {
                LunixiaCompactTimeDrumPicker(
                    hour: time.hour,
                    minute: time.minute,
                    tint: theme.palette.primaryAction
                )
            } else {
                LunixiaGradientTimeDrumPicker(
                    hour: time.hour,
                    minute: time.minute,
                    tint: theme.palette.primaryAction
                )
            }
        }
    }
}

// ============================================================
// MARK: - Dose Schedule Grid
// ============================================================

struct MedDoseScheduleGrid: View {
    @Environment(\.appTheme) private var theme

    @Binding var defaultQuantity: Int
    @Binding var overrides: [Int: Int]
    @State private var fieldText: [Int: String] = [:]

    private let days: [(label: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7),
    ]

    private var allDaysCustom: Bool { overrides.count == 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Default row — visually dimmed when all days are overridden
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(allDaysCustom ? LColors.textSecondary.opacity(0.35) : LColors.textSecondary)
                    if allDaysCustom {
                        Text("all days have a custom value")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.35))
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if defaultQuantity > 1 { defaultQuantity -= 1 }
                    } label: {
                        Image("chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(defaultQuantity <= 1 || allDaysCustom)

                    Text("\(defaultQuantity)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(allDaysCustom ? LColors.textSecondary.opacity(0.35) : LColors.textPrimary)
                        .frame(minWidth: 30, alignment: .center)

                    Button {
                        if defaultQuantity < 99 { defaultQuantity += 1 }
                    } label: {
                        Image("chevup")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(allDaysCustom)
                }
            }

            Divider().overlay(LColors.glassBorder)

            Text("Per-day overrides")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.65))

            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    dayColumn(
                        day,
                        tint: theme.palette.rotation[index % theme.palette.rotation.count]
                    )
                }
            }

            if !overrides.isEmpty && !allDaysCustom {
                Text("Days without a custom value use the default above.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.5))
            }
        }
        .onAppear { syncFieldText() }
        .onChange(of: overrides) { syncFieldText() }
    }

    @ViewBuilder
    private func dayColumn(_ day: (label: String, weekday: Int), tint: Color) -> some View {
        let isSelected = overrides[day.weekday] != nil
        VStack(spacing: 5) {
            Button { toggleDay(day.weekday) } label: {
                Text(day.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        BubblyIconMaterial(tint: tint)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .opacity(isSelected ? 1 : 0.38)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? tint : LColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if isSelected {
                TextField("", text: Binding(
                    get: { fieldText[day.weekday] ?? "\(overrides[day.weekday] ?? defaultQuantity)" },
                    set: { v in
                        fieldText[day.weekday] = v
                        if let p = Int(v.trimmingCharacters(in: .whitespaces)), p > 0 { overrides[day.weekday] = p }
                    }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
            } else {
                Color.clear.frame(height: 28)
            }
        }
    }

    private func toggleDay(_ weekday: Int) {
        if overrides[weekday] != nil { overrides.removeValue(forKey: weekday); fieldText.removeValue(forKey: weekday) }
        else { overrides[weekday] = defaultQuantity; fieldText[weekday] = "\(defaultQuantity)" }
    }

    private func syncFieldText() {
        for (w, q) in overrides where fieldText[w] == nil { fieldText[w] = "\(q)" }
        for w in fieldText.keys where overrides[w] == nil { fieldText.removeValue(forKey: w) }
    }
}

// ============================================================
// MARK: - Direct Refill Date Sheet
// ============================================================

struct MedDirectRefillSheet: View {
    let medication: LunixiaMedication
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme

    @State private var hasRefillDate: Bool
    @State private var refillDate: Date

    init(medication: LunixiaMedication, onSave: @escaping () -> Void) {
        self.medication = medication
        self.onSave = onSave
        _hasRefillDate = State(initialValue: medication.refillDate != nil)
        _refillDate    = State(initialValue: medication.refillDate ?? Date())
    }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {

                HStack {
                    Text("Refill Date")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                    .buttonStyle(.plain)
                }

                MedicationRefillControls(
                    hasRefillDate: $hasRefillDate,
                    refillDate: $refillDate
                )

                Spacer()

                medDoneButton(
                    label: "Save Refill Date",
                    tint: theme.palette.primaryAction
                ) {
                    let previousRefillDate = medication.refillDate
                    let previousAmount = medication.currentAmount
                    let now = Date()
                    let todayKey = MedicationAutomationManager.dayKey(for: now)

                    medication.refillDate = hasRefillDate ? refillDate : nil
                    medication.lastAutoRefillDayKey = ""
                    medication.updatedAt = now

                    if !sameRefillDay(previousRefillDate, medication.refillDate) {
                        modelContext.insert(
                            LunixiaMedHistoryEntry(
                                type: .edited,
                                amountText: "\(previousAmount) → \(previousAmount)",
                                details: "Manual refill date updated.",
                                effectiveDayKey: todayKey,
                                createdAt: now,
                                medication: medication
                            )
                        )
                    }

                    onSave()
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    private func sameRefillDay(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return Calendar.current.isDate(lhs, inSameDayAs: rhs)
        default:
            return false
        }
    }
}

// ============================================================
// MARK: - Inventory Sheet
// ============================================================

struct MedInventorySheet: View {
    let medication: LunixiaMedication
    let onAction: (InventoryAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var adjustedAmount: Int
    @State private var didCommitAdjustment = false

    init(
        medication: LunixiaMedication,
        onAction: @escaping (InventoryAction) -> Void
    ) {
        self.medication = medication
        self.onAction = onAction
        _adjustedAmount = State(initialValue: medication.currentAmount)
    }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    HStack {
                        Text("Adjust Inventory")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Spacer()
                        Button { commitAndDismiss() } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(theme.palette.primaryAction)
                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        inventoryTile(label: "Name",    value: medication.name)
                        inventoryTile(label: "Current", value: "\(medication.currentAmount)")
                        inventoryTile(label: "Supply",  value: "\(medication.supplyAmount)")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionKicker("quick actions")
                        HStack(spacing: 10) {
                            quickBtn("-1")                       { adjustedAmount = max(0, adjustedAmount - 1) }
                            quickBtn("+1")                       { adjustedAmount += 1 }
                            quickBtn("Set Full", tint: theme.palette.primaryAction) { adjustedAmount = max(0, medication.supplyAmount) }
                        }
                    }

                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionKicker("step adjustments")
                            inventoryAdjustmentControl
                        }
                    }

                    Spacer(minLength: 20)
                    medDoneButton(tint: theme.palette.indicators) { commitAndDismiss() }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .onDisappear {
            commitPendingAdjustment()
        }
    }

    @ViewBuilder private func inventoryTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(LColors.textSecondary).kerning(0.5)
            Text(value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(LColors.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
    }

    @ViewBuilder private func quickBtn(_ label: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint == nil ? LColors.textPrimary : Color.white)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background {
                    if let tint {
                        BubblyCardMaterial(tint: tint, cornerRadius: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LColors.glassSurface)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    private var inventoryAdjustmentControl: some View {
        HStack(spacing: 22) {
            InventoryRepeatingAdjustmentButton(
                assetName: "addwavy",
                accessibilityLabel: "Increase inventory"
            ) {
                adjustedAmount += 1
            }

            Text("\(adjustedAmount)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(theme.palette.secondaryAccent)
                .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                .contentTransition(.numericText())
                .frame(minWidth: 72)

            InventoryRepeatingAdjustmentButton(
                assetName: "minuswavy",
                accessibilityLabel: "Decrease inventory",
                isEnabled: adjustedAmount > 0
            ) {
                guard adjustedAmount > 0 else { return }
                adjustedAmount -= 1
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func commitAndDismiss() {
        commitPendingAdjustment()
        dismiss()
    }

    private func commitPendingAdjustment() {
        guard !didCommitAdjustment else { return }
        didCommitAdjustment = true

        let delta = adjustedAmount - medication.currentAmount
        guard delta != 0 else { return }
        onAction(.adjust(delta))
    }
}

private struct InventoryRepeatingAdjustmentButton: View {
    let assetName: String
    let accessibilityLabel: String
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .foregroundStyle(theme.palette.secondaryAccent)
            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
            .frame(width: 54, height: 54)
            .scaleEffect(isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        beginPressIfNeeded()
                    }
                    .onEnded { _ in
                        endPress()
                    }
            )
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard isEnabled else { return }
                action()
            }
            .onDisappear {
                endPress()
            }
    }

    private func beginPressIfNeeded() {
        guard isEnabled, !isPressed else { return }
        isPressed = true
        action()

        repeatTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)

            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 110_000_000)
            }
        }
    }

    private func endPress() {
        isPressed = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}

// ============================================================
// MARK: - History Sheet
// ============================================================

struct MedHistorySheet: View {
    let medication: LunixiaMedication
    var isPremium: Bool = false
    let onDeleteEntry: (LunixiaMedHistoryEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showDeleteConfirm = false
    @State private var entryPendingDeletion: LunixiaMedHistoryEntry? = nil
    @State private var visibleCount = 6
    private let pageSize = 6

    private var allFiltered: [LunixiaMedHistoryEntry] {
        let sortedEntries = (medication.historyEntries ?? []).sorted { $0.createdAt > $1.createdAt }

        if isPremium {
            return sortedEntries
        }

        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.medicationHistoryDaysLimit(isPremium: false)
        )

        return sortedEntries.filter { $0.createdAt >= cutoff }
    }

    private var visibleEntries: [LunixiaMedHistoryEntry] {
        Array(allFiltered.prefix(visibleCount))
    }

    private var totalCount: Int { allFiltered.count }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("History")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

                let entries = visibleEntries
                if entries.isEmpty {
                    Text("No history yet")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center).padding(.top, 40)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                                historyRow(
                                    entry,
                                    tint: theme.palette.rotation[index % theme.palette.rotation.count]
                                )
                            }

                            if totalCount > pageSize {
                                VStack(spacing: 10) {
                                    if visibleCount < totalCount {
                                        Button {
                                            withAnimation { visibleCount = min(visibleCount + pageSize, totalCount) }
                                        } label: {
                                            Text("Load More")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 9)
                                                .background {
                                                    BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                                                        .clipShape(Capsule())
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if visibleCount > pageSize {
                                        Button {
                                            withAnimation { visibleCount = pageSize }
                                        } label: {
                                            Text("See Less")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 9)
                                                .background(
                                                    Capsule().fill(LColors.glassSurface)
                                                        .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 40)
                    }
                }
            }
        }
        .lunixiaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete History Entry",
            message: "Are you sure you want to delete this medication history entry?",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let entry = entryPendingDeletion {
                onDeleteEntry(entry)
                entryPendingDeletion = nil
            }
        }
    }

    @ViewBuilder private func historyRow(_ entry: LunixiaMedHistoryEntry, tint: Color) -> some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.white).kerning(0.8)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background {
                        BubblyIconMaterial(tint: tint)
                            .clipShape(Capsule())
                    }

                VStack(alignment: .leading, spacing: 3) {
                    if !entry.amountText.isEmpty { Text(entry.amountText).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(LColors.textPrimary) }
                    if !entry.details.isEmpty    { Text(entry.details).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(LColors.textSecondary) }
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(LColors.textSecondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onLongPressGesture {
                entryPendingDeletion = entry
                showDeleteConfirm = true
            }
        }
    }

}

// ============================================================
// MARK: - Shared building blocks
// ============================================================

@ViewBuilder
private func medSheetHeader(
    title: String,
    tint: Color,
    onDismiss: @escaping () -> Void
) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(LColors.textPrimary)

        Spacer()

        Button(action: onDismiss) {
            Image("xmarkwavy")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(tint)
                .bubblyIconMaterial(tint: tint)
        }
        .buttonStyle(.plain)
    }
}

@ViewBuilder
private func medDoneButton(
    label: String = "Done",
    tint: Color,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            Image("checkwavy")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 14, height: 14)
            Text(label).font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            BubblyCardMaterial(
                tint: tint,
                cornerRadius: LSpacing.buttonRadius
            )
        }
    }
    .buttonStyle(.plain)
}

@ViewBuilder
private func sectionKicker(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(LColors.textSecondary.opacity(0.55))
        .kerning(1.2)
}

@ViewBuilder
private func medSaveButton(
    label: String,
    tint: Color,
    action: @escaping () -> Void
) -> some View {
    medDoneButton(label: label, tint: tint, action: action)
}
