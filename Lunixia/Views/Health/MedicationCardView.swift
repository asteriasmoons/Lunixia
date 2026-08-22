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
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
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
                            .foregroundStyle(canCreateMedicationCard ? LGradients.header : LinearGradient(colors: [LColors.textSecondary.opacity(0.45)], startPoint: .top, endPoint: .bottom))
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
                                overviewStat(label: "Medications", value: medications.count)
                                    .overlay {
                                        if !canCreateMedicationCard && !isPremium {
                                            LunixiaPremiumBlurOverlay(cornerRadius: 12)
                                        }
                                    }
                                Rectangle()
                                    .fill(LColors.glassBorder)
                                    .frame(width: 1)
                                    .padding(.vertical, 4)
                                overviewStat(label: "Refills (7 days)", value: upcomingRefillCount)
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
                
                MedicationAutomationManager.run(
                    in: modelContext,
                    shouldProcessRefills: false,
                    shouldProcessAutoDecreases: false
                )
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

                MedicationAutomationManager.run(
                    in: modelContext,
                    shouldProcessRefills: false,
                    shouldProcessAutoDecreases: false
                )
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

                    MedicationAutomationManager.run(
                        in: modelContext,
                        shouldProcessRefills: false,
                        shouldProcessAutoDecreases: false
                    )
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

                    MedicationAutomationManager.run(
                        in: modelContext,
                        shouldProcessRefills: false,
                        shouldProcessAutoDecreases: false
                    )
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
                    MedicationAutomationManager.run(
                        in: modelContext,
                        shouldProcessRefills: false,
                        shouldProcessAutoDecreases: false
                    )
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
                    MedicationAutomationManager.run(
                        in: modelContext,
                        shouldProcessRefills: false,
                        shouldProcessAutoDecreases: false
                    )
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
            MedicationAutomationManager.run(in: modelContext)
            _ = await MedicationNotificationManager.shared.requestAuthorization()
        }
    }

    // MARK: - Overview Stat

    @ViewBuilder
    private func overviewStat(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)
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
                                medPill(text: "REFILL: \(shortRefillDate(refill))", color: LColors.gradientPurple.opacity(0.22))
                            }

                            if med.daysSupply > 0 {
                                medPill(text: "SUPPLY DAYS: \(med.daysSupply)", color: LColors.gradientBlue.opacity(0.16))
                            }
                        }

                        if med.notifyDose || med.autoDecreaseEnabled {
                            HStack(spacing: 6) {
                                if med.notifyDose {
                                    medPill(text: "ALERTS: Enabled", color: LColors.success.opacity(0.14))
                                }

                                if med.autoDecreaseEnabled {
                                    medPill(text: "AUTO", color: LColors.gradientPurple.opacity(0.18))
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
                    .background(Capsule().fill(LGradients.blue))
                }
                .buttonStyle(.plain)
                .disabled(med.currentAmount == 0)

                Spacer()

                rowIconButton(asset: "dotswavy") { selectedMed = med; showInventorySheet = true }
                rowIconButton(asset: "clockfill") { selectedMed = med; showHistorySheet = true }
                rowIconButton(asset: "lovecalendar") { selectedMed = med; showRefillSheet = true }
                rowIconButton(asset: "pencil") { selectedMed = med; showEditSheet = true }
                rowIconButton(asset: "trash", tint: LColors.gradientPurple.opacity(0.75)) { selectedMed = med; showDeleteConfirm = true }
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

                Circle()
                    .fill(isFilled ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassBorder.opacity(0.45)))
                    .frame(width: dotSize, height: dotSize)
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
    private func medPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(LColors.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
            .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 0.75))
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
// MARK: - Add / Edit Sheet
// ============================================================

struct MedAddEditSheet: View {
    enum Mode { case add; case edit(LunixiaMedication) }

    let mode: Mode
    let onSave: (LunixiaMedication) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
                            .foregroundStyle(LGradients.header)
                        Spacer()
                        Button { dismiss() } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(LGradients.header)
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
                        configRow(asset: "lovecalendar", label: "Refill Date",   summary: refillSummary,   position: .top)    { showRefillSheet   = true }
                        groupedDivider()
                        configRow(asset: "pilldrop",     label: "Dose Schedule", summary: scheduleSummary, position: .middle) { showScheduleSheet  = true }
                        groupedDivider()
                        configRow(asset: "bellfill",     label: "Notifications", summary: notifySummary,   position: .bottom) { showNotifySheet    = true }
                    }

                    // ── Auto Decrease ──────────────────────────────────────
                    autoDecreaseSection

                    medSaveButton(label: "Save Medication") { save() }
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
    private func configRow(asset: String, label: String, summary: String, position: RowPosition, action: @escaping () -> Void) -> some View {
        let c = corners(for: position)
        Button(action: action) {
            HStack(spacing: 12) {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(LGradients.header)
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
                    Toggle(isOn: $autoDecreaseEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Auto Decrease")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)

                            Text("Automatically subtract the scheduled dose amount once per day.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(LColors.accent)

                    if autoDecreaseEnabled {
                        Divider()
                            .overlay(LColors.glassBorder)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Decrease Time")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)

                                    Text("Inventory updates at this time or the next time Lunixia becomes active afterward.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Text(autoDecreaseTimeDisplayString)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(LGradients.header)
                            }

                            LunixiaGradientTimeDrumPicker(
                                hour: $autoDecreaseHour,
                                minute: $autoDecreaseMinute
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

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {

                HStack {
                    Text("Refill Date")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }

                GlassCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $includeRefillDate) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Set a refill date")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                Text("Auto-refills supply and advances the date when due.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                            }
                        }
                        .tint(LColors.accent)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LGradients.blue.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(LGradients.header, lineWidth: 1.2)
                        )

                        if includeRefillDate {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionKicker("refill date")
                                DatePicker("", selection: $refillDate, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .colorScheme(.dark)
                                    .labelsHidden()
                                    .tint(LColors.accent)
                            }
                        }
                    }
                }

                Spacer()
                medDoneButton { dismiss() }
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

    private let days: [(label: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7),
    ]

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    medSheetHeader(title: "Dose Schedule") { dismiss() }

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
                    medDoneButton { dismiss() }
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
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.black.opacity(0.78) : LColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface2),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isSelected ? AnyShapeStyle(LColors.gradientBlue.opacity(0.5)) : AnyShapeStyle(LColors.glassBorder), lineWidth: 0.85)
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
                    ForEach(days, id: \.weekday) { day in
                        let isSelected = weeklyWeekday == day.weekday
                        Button {
                            weeklyWeekday = day.weekday
                        } label: {
                            Text(day.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.black.opacity(0.75) : LColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface2),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? AnyShapeStyle(LColors.gradientBlue.opacity(0.5)) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1)
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
                            .foregroundStyle(defaultDoses <= 1 ? LColors.textSecondary.opacity(0.3) : Color.black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                defaultDoses <= 1 ? AnyShapeStyle(LColors.glassSurface2) : AnyShapeStyle(LGradients.blue),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
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
                            .foregroundStyle(Color.black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(LGradients.blue, in: RoundedRectangle(cornerRadius: 9))
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

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    medSheetHeader(title: "Notifications") { dismiss() }

                    // ── Dose reminders ────────────────────────────────────
                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $notifyDose) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Dose reminders")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    Text("Get notified at each time you add below.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                }
                            }
                            .tint(LColors.accent)

                            if notifyDose {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach($doseNotifyTimes) { $time in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(time.displayString)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundStyle(LGradients.header)
                                                Spacer()
                                                if doseNotifyTimes.count > 1 {
                                                    Button {
                                                        withAnimation {
                                                            doseNotifyTimes.removeAll { $0.id == time.id }
                                                        }
                                                    } label: {
                                                        Image("trash")
                                                            .renderingMode(.template)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 14, height: 14)
                                                            .foregroundStyle(LColors.danger.opacity(0.7))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            LunixiaGradientTimeDrumPicker(hour: $time.hour, minute: $time.minute)
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(LColors.glassSurface2)
                                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                                        )
                                    }

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
                                            Text("Add reminder time")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(LGradients.header)
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
                            Toggle(isOn: $notifyRefill) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Refill reminder")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    Text("Get notified a few days before your refill date.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                }
                            }
                            .tint(LColors.accent)

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
                                                .foregroundStyle(daysBeforeRefill <= 1 ? LColors.textSecondary.opacity(0.3) : Color.black.opacity(0.8))
                                                .frame(width: 36, height: 36)
                                                .background(
                                                    daysBeforeRefill <= 1 ? AnyShapeStyle(LColors.glassSurface2) : AnyShapeStyle(LGradients.blue),
                                                    in: RoundedRectangle(cornerRadius: 10)
                                                )
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
                                                .foregroundStyle(Color.black.opacity(0.8))
                                                .frame(width: 36, height: 36)
                                                .background(LGradients.blue, in: RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                    medDoneButton { dismiss() }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
}

// ============================================================
// MARK: - Dose Schedule Grid
// ============================================================

struct MedDoseScheduleGrid: View {
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
                            .foregroundStyle((defaultQuantity <= 1 || allDaysCustom) ? LColors.textSecondary.opacity(0.3) : Color.black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                (defaultQuantity <= 1 || allDaysCustom) ? AnyShapeStyle(LColors.glassSurface2) : AnyShapeStyle(LGradients.blue),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
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
                            .foregroundStyle(allDaysCustom ? LColors.textSecondary.opacity(0.3) : Color.black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                allDaysCustom ? AnyShapeStyle(LColors.glassSurface2) : AnyShapeStyle(LGradients.blue),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
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
                ForEach(days, id: \.weekday) { day in
                    dayColumn(day)
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
    private func dayColumn(_ day: (label: String, weekday: Int)) -> some View {
        let isSelected = overrides[day.weekday] != nil
        VStack(spacing: 5) {
            Button { toggleDay(day.weekday) } label: {
                Text(day.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.75) : LColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface2),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? AnyShapeStyle(LColors.gradientBlue.opacity(0.5)) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1)
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
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }

                GlassCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $hasRefillDate) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Set a refill date")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                Text("Auto-refills supply and advances the date when due.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                            }
                        }
                        .tint(LColors.accent)

                        if hasRefillDate {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionKicker("refill date")
                                DatePicker("", selection: $refillDate, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .colorScheme(.dark)
                                    .labelsHidden()
                                    .tint(LColors.accent)
                            }
                        }
                    }
                }

                Spacer()

                medDoneButton(label: "Save Refill Date") {
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
    @State private var increaseAmt = 1
    @State private var decreaseAmt = 1

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    HStack {
                        Text("Adjust Inventory")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Spacer()
                        Button { dismiss() } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(LGradients.header)
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
                            quickBtn("-1")                       { onAction(.adjust(-1)) }
                            quickBtn("+1")                       { onAction(.adjust(1)) }
                            quickBtn("Set Full", gradient: true) { onAction(.setFull) }
                        }
                    }

                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionKicker("step adjustments")
                            stepRow(label: "Increase by", value: $increaseAmt, sign: "+", gradient: true)  { onAction(.adjust(increaseAmt)) }
                            stepRow(label: "Decrease by", value: $decreaseAmt, sign: "-", gradient: false) { onAction(.adjust(-decreaseAmt)) }
                        }
                    }

                    Spacer(minLength: 20)
                    medDoneButton { dismiss() }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
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

    @ViewBuilder private func quickBtn(_ label: String, gradient: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(gradient ? Color.white : LColors.textPrimary)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(gradient ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func stepRow(label: String, value: Binding<Int>, sign: String, gradient: Bool, onApply: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(LColors.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                Button { if value.wrappedValue > 1 { value.wrappedValue -= 1 } } label: {
                    Image("chevdown").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 12, height: 12).foregroundStyle(LColors.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                }.buttonStyle(.plain)
                Text("\(sign)\(value.wrappedValue)").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(LColors.textPrimary).frame(minWidth: 26, alignment: .center)
                Button { if value.wrappedValue < 100 { value.wrappedValue += 1 } } label: {
                    Image("chevup").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(gradient ? Color.black.opacity(0.8) : LColors.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(gradient ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                }.buttonStyle(.plain)
                Button(action: onApply) {
                    HStack(spacing: 4) {
                        Image("checkwavy").renderingMode(.template).resizable().scaledToFit().frame(width: 11, height: 11)
                        Text("Apply").font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                    .frame(minWidth: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LGradients.blue, in: Capsule())
                }.buttonStyle(.plain)
            }
        }
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
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
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
                            ForEach(entries) { entry in historyRow(entry) }

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
                                                .background(LColors.accentGradient, in: Capsule())
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

    @ViewBuilder private func historyRow(_ entry: LunixiaMedHistoryEntry) -> some View {
        GlassCard(padding: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(entry.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.white).kerning(0.8)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(typeBadgeColor(entry.type), in: Capsule())
                VStack(alignment: .leading, spacing: 3) {
                    if !entry.amountText.isEmpty { Text(entry.amountText).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(LColors.textPrimary) }
                    if !entry.details.isEmpty    { Text(entry.details).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(LColors.textSecondary) }
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(LColors.textSecondary.opacity(0.5))
                }
                Spacer()
            }
            .onLongPressGesture {
                entryPendingDeletion = entry
                showDeleteConfirm = true
            }
        }
    }

    private func typeBadgeColor(_ type: LunixiaMedHistoryEntry.EntryType) -> AnyShapeStyle {
        switch type {
        case .taken:    return AnyShapeStyle(LGradients.blue)
        case .refilled: return AnyShapeStyle(LinearGradient(colors: [LColors.success, LColors.gradientBlue], startPoint: .leading, endPoint: .trailing))
        case .edited:   return AnyShapeStyle(LinearGradient(colors: [LColors.gradientPurple, LColors.gradientBlue], startPoint: .leading, endPoint: .trailing))
        }
    }
}

// ============================================================
// MARK: - Shared building blocks
// ============================================================

@ViewBuilder
private func medSheetHeader(title: String, onDismiss: @escaping () -> Void) -> some View {
    HStack {
        Button(action: onDismiss) {
            Image("xmarkwavy")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(LGradients.header)
        }
        .buttonStyle(.plain)
        Spacer()
        Text(title)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(LGradients.header)
        Spacer()
        Color.clear.frame(width: 22, height: 22)
    }
}

@ViewBuilder
private func medDoneButton(label: String = "Done", action: @escaping () -> Void) -> some View {
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
        .background(
            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                .fill(LColors.accentGradient)
                .shadow(color: LColors.gradientPurple.opacity(0.35), radius: 12, y: 6)
        )
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
private func medSaveButton(label: String, action: @escaping () -> Void) -> some View {
    medDoneButton(label: label, action: action)
}
