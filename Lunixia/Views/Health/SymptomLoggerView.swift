//
//  SymptomLoggerView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

// MARK: - Symptom Logger Page

struct SymptomLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \LunixiaSymptomLog.date, order: .reverse) private var logs: [LunixiaSymptomLog]

    @State private var showLogSheet      = false
    @State private var showDeleteConfirm = false
    @State private var selectedLog: LunixiaSymptomLog? = nil
    @State private var detailLog: LunixiaSymptomLog? = nil
    @State private var editingLog: LunixiaSymptomLog?  = nil
    @State private var showBanner        = false
    @State private var bannerMessage     = ""

    @State private var formSymptoms: [String] = []
    @State private var formSeverity: Int = 0
    @State private var formNote: String = ""
    @State private var formDate: Date = Date()

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var logsThisWeek: Int {
        logsInSevenDayWindow.count
    }

    private var logsInSevenDayWindow: [LunixiaSymptomLog] {
        let cutoff = LunixiaLimitsManager.startOfSevenDayWindow()
        return logs.filter { $0.date >= cutoff }
    }

    private var canCreateSymptomLog: Bool {
        LunixiaLimitsManager.canCreateSymptomLog(
            currentSevenDayCount: logsInSevenDayWindow.count,
            isPremium: isPremium
        )
    }

    private var cardTints: [Color] {
        [theme.palette.primaryAction, theme.palette.secondaryAccent, theme.palette.indicators]
    }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Nav
                HStack(spacing: 16) {
                    Text("Symptom Log")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                    .buttonStyle(.plain)
                    Button {
                        if canCreateSymptomLog {
                            resetForm()
                            showLogSheet = true
                        } else {
                            showPremiumRequiredMessage()
                        }
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(
                                canCreateSymptomLog
                                ? AnyShapeStyle(theme.palette.secondaryAccent)
                                : AnyShapeStyle(LColors.textSecondary.opacity(0.45))
                            )
                            .bubblyIconMaterial(
                                tint: canCreateSymptomLog
                                    ? theme.palette.secondaryAccent
                                    : LColors.textSecondary.opacity(0.45)
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
                                    label: "Total Logged",
                                    value: logs.count,
                                    tint: theme.palette.primaryAction
                                )
                                Rectangle()
                                    .fill(LColors.glassBorder)
                                    .frame(width: 1)
                                    .padding(.vertical, 4)
                                overviewStat(
                                    label: "This Week",
                                    value: logsThisWeek,
                                    tint: theme.palette.secondaryAccent
                                )
                                    .overlay {
                                        if !canCreateSymptomLog && !isPremium {
                                            LunixiaPremiumBlurOverlay(cornerRadius: 12)
                                        }
                                }
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(theme.palette.primaryAction, lineWidth: 1)
                        }
                        .padding(.horizontal, 16)

                        // MARK: Log cards
                        if logs.isEmpty {
                            GlassCard(padding: 20) {
                                Text("no symptoms logged yet")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.45))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                                logCard(log, tint: cardTints[index % cardTints.count])
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
        .sheet(isPresented: $showLogSheet) {
            SymptomLogSheet(
                editingLog: editingLog,
                symptoms: $formSymptoms,
                severity: $formSeverity,
                note: $formNote,
                date: $formDate
            ) {
                saveLog()
            }
        }
        .sheet(item: $detailLog) { log in
            SymptomDetailSheet(log: log) {
                detailLog = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    loadForEdit(log)
                    showLogSheet = true
                }
            } onDelete: {
                detailLog = nil
                selectedLog = log
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showDeleteConfirm = true
                }
            }
        }
        .lunixiaAlertConfirm(
            isPresented: $showDeleteConfirm,
            title: "Delete Entry",
            message: "Are you sure you want to delete this symptom entry?",
            confirmTitle: "Delete",
            confirmRole: .destructive
        ) {
            if let log = selectedLog {
                modelContext.delete(log)
                try? modelContext.save()
                selectedLog = nil
                flash("Entry deleted")
            }
        }
    }

    // MARK: - Overview stat

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

    // MARK: - Log card

    @ViewBuilder
    private func logCard(_ log: LunixiaSymptomLog, tint: Color) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Image("scope")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(theme.palette.primaryAction)
                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }

                        if log.severity > 0, let label = LunixiaSymptomLog.severityLabels[log.severity] {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                Text(label)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(symptomSeverityColor(log.severity))
                                    .bubblyIconMaterial(tint: symptomSeverityColor(log.severity))
                            }
                        }
                    }

                    Spacer()

                    rowIconButton(asset: "dotswavy") {
                        detailLog = log
                    }
                    rowIconButton(asset: "pencil") {
                        loadForEdit(log)
                        showLogSheet = true
                    }
                    rowIconButton(asset: "trash", tint: tint) {
                        selectedLog = log
                        showDeleteConfirm = true
                    }
                }

                if !log.symptoms.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(log.symptoms, id: \.self) { symptom in
                            symptomPill(symptom)
                        }
                    }
                }

                if !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(log.note)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(tint, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func symptomPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(LColors.textSecondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(LColors.glassSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 0.75))
    }

    @ViewBuilder
    private func rowIconButton(asset: String, tint: Color = LColors.textSecondary.opacity(0.7), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset)
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(tint)
                .bubblyIconMaterial(tint: tint)
                .frame(width: 30, height: 30)
                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func resetForm() {
        editingLog = nil
        formSymptoms = []
        formSeverity = 0
        formNote = ""
        formDate = Date()
    }

    private func loadForEdit(_ log: LunixiaSymptomLog) {
        editingLog = log
        formSymptoms = log.symptoms
        formSeverity = log.severity
        formNote = log.note
        formDate = log.date
    }

    private func saveLog() {
        guard !formSymptoms.isEmpty else { return }

        if editingLog == nil && !canCreateSymptomLog {
            showPremiumRequiredMessage()
            return
        }

        if let existing = editingLog {
            existing.symptoms = formSymptoms
            existing.severity = formSeverity
            existing.note = formNote.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.date = formDate
            existing.updatedAt = Date()
            flash("Entry updated")
        } else {
            let log = LunixiaSymptomLog(
                symptoms: formSymptoms,
                severity: formSeverity,
                note: formNote.trimmingCharacters(in: .whitespacesAndNewlines),
                date: formDate
            )
            modelContext.insert(log)
            flash("Symptoms logged")
        }
        try? modelContext.save()
        resetForm()
    }

    private func showPremiumRequiredMessage() {
        flash("Premium unlocks more symptom logs.")
    }

    private func flash(_ message: String) {
        bannerMessage = message
        withAnimation { showBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { showBanner = false } }
    }
}

// ============================================================
// MARK: - Log / Edit Sheet
// ============================================================

struct SymptomLogSheet: View {
    let editingLog: LunixiaSymptomLog?
    @Binding var symptoms: [String]
    @Binding var severity: Int
    @Binding var note: String
    @Binding var date: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var symptomsExpanded = false

    private var isEditing: Bool { editingLog != nil }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    HStack {
                        Text(isEditing ? "Edit Entry" : "Log Symptoms")
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

                    // ── Date ─────────────────────────────────────────────
                    sheetSection(label: "date", showsOuterCard: false) {
                        HStack(alignment: .top, spacing: 10) {
                            LunixiaCompactDateDrumPicker(
                                date: $date,
                                tint: theme.palette.primaryAction,
                                usesCardMaterial: true
                            )
                            .frame(maxWidth: .infinity)

                            LunixiaCompactTimeDrumPicker(
                                hour: hourBinding,
                                minute: minuteBinding,
                                tint: theme.palette.primaryAction
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // ── Symptoms ──────────────────────────────────────────
                    sheetSection(label: "symptoms", showsOuterCard: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    symptomsExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(symptoms.isEmpty ? "Select symptoms" : "\(symptoms.count) selected")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Image(symptomsExpanded ? "chevup" : "chevdown")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 13, height: 13)
                                        .foregroundStyle(theme.palette.secondaryAccent)
                                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .bubblyCardMaterial(
                                    tint: theme.palette.secondaryAccent,
                                    cornerRadius: 14
                                )
                            }
                            .buttonStyle(.plain)

                            if symptomsExpanded {
                                ScrollView(.vertical, showsIndicators: true) {
                                    LazyVStack(spacing: 0) {
                                        ForEach(LunixiaSymptomLog.allSymptoms, id: \.self) { symptom in
                                            symptomOptionRow(symptom)
                                        }
                                    }
                                }
                                .frame(height: 176)
                                .bubblyCardMaterial(
                                    tint: theme.palette.secondaryAccent,
                                    cornerRadius: 14
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    // ── Severity ──────────────────────────────────────────
                    sheetSection(label: "severity", borderColor: theme.palette.indicators) {
                        VStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { level in
                                severityRow(level: level)
                                if level < 5 {
                                    Rectangle().fill(LColors.glassBorder).frame(height: 0.75).padding(.leading, 16)
                                }
                            }
                        }
                    }

                    // ── Note ─────────────────────────────────────────────
                    sheetSection(label: "note (optional)", borderColor: theme.palette.primaryAction) {
                        TextField("Add a note...", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled()
                            .foregroundStyle(LColors.textPrimary)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }

                    // Save
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image("checkwavy")
                                .renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)
                                .bubblyIconMaterial(tint: .white)
                            Text(isEditing ? "Save Changes" : "Log Symptoms")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .bubblyCardMaterial(
                            tint: theme.palette.secondaryAccent,
                            cornerRadius: LSpacing.buttonRadius
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(symptoms.isEmpty)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    @ViewBuilder
    private func sheetSection<Content: View>(
        label: String,
        borderColor: Color? = nil,
        showsOuterCard: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.55))
                .kerning(1.2)
            if showsOuterCard {
                GlassCard(cornerRadius: 14, padding: 0) {
                    VStack(spacing: 0) {
                        content()
                    }
                }
                .overlay {
                    if let borderColor {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    @ViewBuilder
    private func symptomOptionRow(_ symptom: String) -> some View {
        let selected = symptoms.contains(symptom)
        Button {
            if selected { symptoms.removeAll { $0 == symptom } }
            else        { symptoms.append(symptom) }
        } label: {
            HStack(spacing: 10) {
                Text(symptom)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if selected {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(theme.palette.secondaryAccent)
                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.white.opacity(selected ? 0.12 : 0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: selected)
    }

    @ViewBuilder
    private func severityRow(level: Int) -> some View {
        let selected = severity == level
        let label = LunixiaSymptomLog.severityLabels[level] ?? ""
        Button {
            severity = selected ? 0 : level
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(selected ? Color.white : LColors.glassBorder)
                    .bubblyIconMaterial(
                        tint: selected ? .white : LColors.glassBorder
                    )
                    .frame(width: 8, height: 8)
                Text("\(level)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(selected ? Color.white : LColors.textSecondary)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Color.white : LColors.textSecondary)
                Spacer()
                if selected {
                    Image("checkwavy")
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.white)
                        .bubblyIconMaterial(tint: .white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background {
                if selected {
                    BubblyCardMaterial(
                        tint: theme.palette.indicators,
                        cornerRadius: 0
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: selected)
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: date) },
            set: { setDateComponent(.hour, to: $0) }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: date) },
            set: { setDateComponent(.minute, to: $0) }
        )
    }

    private func setDateComponent(_ component: Calendar.Component, to value: Int) {
        let calendar = Calendar.current
        guard let updated = calendar.date(bySetting: component, value: value, of: date) else { return }
        date = updated
    }
}

// ============================================================
// MARK: - Detail Sheet
// ============================================================

struct SymptomDetailSheet: View {
    let log: LunixiaSymptomLog
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    HStack {
                        Text("Entry Detail")
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

                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            detailRow(icon: "lovecalendar", label: "Date", value: log.date.formatted(date: .long, time: .shortened))
                            if log.severity > 0, let label = LunixiaSymptomLog.severityLabels[log.severity] {
                                Divider().overlay(LColors.glassBorder)
                                HStack(spacing: 10) {
                                    Image("heartpulse")
                                        .renderingMode(.template).resizable().scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(theme.palette.primaryAction)
                                        .bubblyIconMaterial(tint: theme.palette.primaryAction)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SEVERITY")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                            .kerning(1)
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(symptomSeverityColor(log.severity))
                                                .bubblyIconMaterial(tint: symptomSeverityColor(log.severity))
                                                .frame(width: 7, height: 7)
                                            Text("\(log.severity) — \(label)")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(symptomSeverityColor(log.severity))
                                                .bubblyIconMaterial(tint: symptomSeverityColor(log.severity))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !log.symptoms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SYMPTOMS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                .kerning(1.2)
                            FlowLayout(spacing: 7) {
                                ForEach(log.symptoms, id: \.self) { symptom in
                                    Text(symptom)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                        .padding(.horizontal, 11).padding(.vertical, 7)
                                        .background(LColors.glassSurface, in: Capsule())
                                        .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                                }
                            }
                            .padding(16)
                            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                        }
                    }

                    if !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                .kerning(1.2)
                            Text(log.note)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                            onDelete()
                        } label: {
                            HStack(spacing: 6) {
                                Image("trash")
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .frame(width: 13, height: 13)
                                    .foregroundStyle(LColors.danger)
                                    .bubblyIconMaterial(tint: LColors.danger)
                                Text("Delete")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(LColors.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                    .fill(LColors.danger.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous).strokeBorder(LColors.danger.opacity(0.35), lineWidth: 0.75))
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismiss()
                            onEdit()
                        } label: {
                            HStack(spacing: 6) {
                                Image("pencilcircle")
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .frame(width: 13, height: 13)
                                    .foregroundStyle(.white)
                                    .bubblyIconMaterial(tint: .white)
                                Text("Edit Entry")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .bubblyCardMaterial(
                                tint: theme.palette.indicators,
                                cornerRadius: LSpacing.buttonRadius
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(icon)
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(theme.palette.primaryAction)
                .bubblyIconMaterial(tint: theme.palette.primaryAction)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
                    .kerning(1)
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
            }
        }
    }
}

// MARK: - Severity color helper (SwiftUI — kept out of the model)

func symptomSeverityColor(_ severity: Int) -> Color {
    switch severity {
    case 1: return Color(red: 0.03, green: 0.86, blue: 0.99)
    case 2: return Color(red: 0.49, green: 0.90, blue: 0.40)
    case 3: return Color(red: 1.0,  green: 0.80, blue: 0.20)
    case 4: return Color(red: 1.0,  green: 0.55, blue: 0.20)
    case 5: return Color(red: 1.0,  green: 0.25, blue: 0.35)
    default: return Color.white.opacity(0.6)
    }
}
