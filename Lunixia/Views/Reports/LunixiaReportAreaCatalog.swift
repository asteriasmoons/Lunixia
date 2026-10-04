//
//  LunixiaReportAreaCatalog.swift
//  Lunixia
//
//  Hierarchical report areas: a top-level Category (group) drives a dependent
//  Area (specific item) dropdown. Kept verbatim from the product taxonomy.
//

import Foundation

extension LunixiaReportFormOptions {

    /// Top-level report categories (parent dropdown), in display order.
    static let areaGroups: [String] = [
        "App-Wide / General",
        "Mood",
        "Health",
        "Journal",
        "Notes",
        "Spiritual",
        "Profile & Account",
        "Self-Care Points",
        "Premium / Purchases",
        "Voice / Audio",
        "Apple Health / Device Data",
        "AI / Generated Content",
        "Siri / Shortcuts / App Intents",
        "Widgets",
        "Design / Shared Interface",
        "Data / Persistence",
        "Notifications & Automation",
        "Behavior / Tracking"
    ]

    /// Specific areas (child dropdown) for each category.
    static let areasByGroup: [String: [String]] = [
        "App-Wide / General": [
            "Entire App", "App Launch", "App State", "Main Navigation", "Floating Tab Bar",
            "Overflow Navigation Menu", "Screen Navigation", "Sheets / Full-Screen Covers",
            "Confirmation Dialogs", "Completion Messages", "iPhone Layout", "iPad Layout",
            "Text Input Behavior", "App Theme", "Colors / Gradients", "Shared UI Components",
            "Fonts / Typography", "Icons / Icon Picker", "Images / Assets", "Data Storage",
            "Saved Data", "App Limits", "Premium Access", "StoreKit / Purchases", "Permissions",
            "Keychain", "Shortcuts", "Widgets", "Widget Data Refresh"
        ],
        "Mood": [
            "Mood Home", "Mood Logging", "Mood Log Form", "Emotions", "Emotion Selection",
            "Emotion Bubble Display", "Activities", "Activity Selection", "Activity Bubble Display",
            "Mood Notes", "Mood Date / Time", "Today’s Mood", "Mood History", "Mood History Visibility",
            "Mood Entry Details", "Editing Mood Entries", "Deleting Mood Entries", "Mood Streak",
            "Unique Emotions Count", "Wellness Momentum", "Seven-Day Mood Data", "Emotion Breakdown",
            "Top Emotion", "Top Activity", "Mood Statistics", "Mood Stats Aggregation",
            "Mood Stats Context", "Mood Insights", "Mood Insights History", "Mood AI Analysis",
            "Mood Chat / Talk It Out", "Mood Chat Messages", "Mood Chat AI", "Mood Chat Cooldown",
            "Mood Free/Premium Limits", "Mood History Limits", "Mood Premium Messages",
            "Mood Widget Data", "Mood Widget", "Log Mood Shortcut"
        ],
        "Health": [
            "Health Home", "Health Goals", "Health Goal Editor", "Body & Emotional State",
            "Body State", "Emotional State", "HRV / Heart Rate Variability", "HealthKit",
            "HealthKit Permissions", "HealthKit Reading / Import", "HealthKit Writing / Export",
            "Health History", "Medications", "Medication List", "Medication Details",
            "Adding Medication", "Editing Medication", "Deleting Medication", "Medication Doses",
            "Medication Schedule", "Medication Supply / Quantity", "Medication Auto-Decrement",
            "Medication Automation", "Medication Refill Tracking", "Medication Refill Notifications",
            "Medication Notifications", "Symptoms", "Symptom Logger", "Adding Symptom Logs",
            "Editing Symptom Logs", "Deleting Symptom Logs", "Symptom History", "Sleep", "Sleep Data",
            "Sleep Goal", "Previous Night Sleep", "Naps", "Nap Logging", "Nap History", "Vitals",
            "Vitals Logging", "Vitals History", "Vitals Entry Details", "Editing Vitals",
            "Blood Pressure", "Oxygen / SpO₂", "Temperature", "Weight", "Other Vitals Data",
            "Exercise", "Exercise Logging", "Exercise History", "Exercise Entry Details",
            "Editing Exercise Logs", "Water", "Water Logging", "Inline Water Logging",
            "Clearing Water", "Water History", "Water Goal", "Water Goal Celebration",
            "HealthKit Water Data", "Steps", "Step Count", "Steps History", "Health Metrics History",
            "Health Free/Premium Limits", "Vitals History Limits", "Exercise History Limits",
            "Health Widget Data", "Health Widget", "Log Vitals Shortcut", "Log Exercise Shortcut",
            "Log Water Shortcut"
        ],
        "Journal": [
            "Journal Home", "Journal Books", "Journal Book Creation", "Journal Book Editing",
            "Journal Book Covers", "Journal Entries", "Journal Entry Creation", "Journal Entry Editing",
            "Journal Entry Viewing", "Journal Entry Deletion", "Journal Entry Cards",
            "Journal Entry Date / Time", "Journal Entry Identity / Header", "Journal Entry Tags",
            "Journal Search / Filtering", "Journal Prompts", "Journal Prompt Generation",
            "Journal Prompt Usage / Limits", "Daily Intention", "Daily Intention Creation",
            "Daily Intention AI", "Journal Analysis", "Journal AI Analysis", "Journal Analysis Results",
            "Journal Analysis Overlay", "Journal Analysis Sheet", "Theme Insights",
            "Theme Insights Generation", "Theme Insights Backfill", "Journal Statistics",
            "Journal Blocks", "Block Display / Rendering", "Block Editor", "Block Editing Page",
            "Block Preview", "Block Reordering / Rows", "Paragraph / Text Blocks", "Headings", "Lists",
            "Checklists", "Quotes", "Callouts", "Callout Icons", "Dividers", "Divider Styles",
            "Code Blocks", "Code Syntax Highlighting", "Images / Photos in Journal", "Drawings",
            "PencilKit Drawing", "Tables", "Table Editor", "Table Cells", "Table Formatting",
            "Table Cell Colors", "Journal Body Font", "Font Picker", "Text Color", "Inner Page Styling",
            "Inner Page Settings", "Page Background", "Background Settings",
            "Cover Photo / Background Photo", "Background Color", "Background Opacity",
            "Journal Presentation / Preview", "Journal Book Relationships", "Journal Data Persistence",
            "Add Journal Entry Shortcut / App Intent", "Log Daily Intention Shortcut / App Intent"
        ],
        "Notes": [
            "Notes Home", "Note Creation", "Note Editing", "Note Viewing", "Note Deletion",
            "Note Content", "Note Title", "Note Body", "Sticky Notes", "Note Formatting", "Note Font",
            "Note Font Picker", "Note Font Size", "Note Text Color", "Note Background / Appearance",
            "Note Lists", "Bulleted Lists", "Numbered Lists", "Checklists", "Checklist Items",
            "List Groups", "List Placement", "List Editing", "Completed Checklist Items",
            "Note Rendering / Preview", "Notes Data Persistence", "Sticky Note Widget",
            "Sticky Note Widget Content", "Sticky Note Widget Checklists",
            "Sticky Note Widget Refresh / Data Writer"
        ],
        "Spiritual": [
            "Spiritual Home", "Horoscope", "Daily Horoscope", "Horoscope Data / Generation",
            "Horoscope History / Saved Record", "Moon Phase", "Current Moon Phase",
            "Moon Phase Calculation", "Moon Phase Details", "Moon Phase AI", "Moon Phase Widget",
            "Tarot", "Tarot Cards / Card Data", "Tarot Readings", "Tarot Tips", "Lenormand",
            "Lenormand Cards / Card Data", "Lenormand Readings", "Lenormand Tips",
            "Spiritual AI / Service Requests", "Spiritual Data / Results"
        ],
        "Profile & Account": [
            "Profile", "User Profile Information", "Profile Loading / Saving", "Sign In", "Sign Out",
            "Authentication", "Authentication State", "User Account",
            "Secure Authentication Data / Keychain"
        ],
        "Self-Care Points": [
            "Self-Care Points Home", "Points Balance", "Earning Points", "Points History",
            "Point Sources", "Self-Care Activity / Source Tracking", "Points Calculations",
            "Points Persistence", "Points Widget", "Points Widget Data / Refresh"
        ],
        "Premium / Purchases": [
            "Premium Page", "Premium Status", "Subscription / Purchase", "StoreKit Products",
            "Purchase Processing", "Restore Purchases", "Premium Feature Unlocking",
            "Free vs Premium Limits", "Premium History Limits", "Premium Usage Limits",
            "Premium Prompts / Upgrade Messages"
        ],
        "Voice / Audio": [
            "Voice Input", "Voice Recording", "Voice Transcription", "Microphone Permission",
            "Speech Recognition / Transcription Results"
        ],
        "Apple Health / Device Data": [
            "HealthKit Integration", "HealthKit Authorization", "Reading Health Data",
            "Writing Health Data", "Health Data Backfill", "Step Updates", "HRV Data", "Sleep Data",
            "Water Data", "Vitals Data", "Exercise Data", "Health History / Snapshots", "Device Activity"
        ],
        "AI / Generated Content": [
            "AI Features — General", "Journal AI Analysis", "Daily Intention AI", "Mood AI Analysis",
            "Mood Chat AI", "Theme Insights", "Horoscope Service", "Moon AI", "Spiritual AI",
            "AI Requests / Network Errors", "AI Response Loading", "AI Response Parsing / Display",
            "AI Usage Limits"
        ],
        "Siri / Shortcuts / App Intents": [
            "Apple Shortcuts Integration", "Add Journal Entry", "Log Daily Intention", "Log Mood",
            "Log Vitals", "Log Exercise", "Log Water", "Shortcut Input Validation",
            "Shortcut Data Saving", "Shortcut Results / Responses"
        ],
        "Widgets": [
            "Widgets — General", "Health Widget", "Mood Widget", "Moon Phase Widget",
            "Self-Care Points Widget", "Sticky Note Widget", "Widget Configuration",
            "Widget Appearance", "Widget Data", "Widget Refresh", "Widget Timeline",
            "Widget Fonts / Assets", "App-to-Widget Data Sharing"
        ],
        "Design / Shared Interface": [
            "Background", "Theme", "Color Tokens", "Gradients", "Typography", "Shared Fonts",
            "Icon Library", "Icon Picker", "Glass Cards", "Shared Buttons", "Shared Controls",
            "Shared Cards", "Shared Headers", "Spacing / Layout", "Safe Areas",
            "Animations / Transitions", "Loading States", "Empty States", "Touch / Tap Targets",
            "Scrolling", "Adaptive Sheet Presentation", "iPhone vs iPad Presentation"
        ],
        "Data / Persistence": [
            "SwiftData — General", "Model Saving", "Model Loading", "Model Updating", "Model Deletion",
            "Relationships Between Records", "Data Migration / Model Compatibility", "Journal Data",
            "Mood Data", "Health Data", "Medication Data", "Note Data", "Spiritual Data",
            "Self-Care Points Data", "User/Profile Data", "Local Preferences / Settings",
            "Secure Keychain Data"
        ],
        "Notifications & Automation": [
            "Notifications — General", "Notification Permission", "Medication Notifications",
            "Medication Reminder Scheduling", "Medication Refill Notifications",
            "Medication Automation / Auto-Decrement", "Background Medication Refresh",
            "Notification Timing", "Notification Delivery"
        ],
        "Behavior / Tracking": [
            "Lunixia Behavior Tracking", "Activity Tracking", "Device Activity",
            "Usage-Dependent Behavior", "Feature Limits / Counters"
        ]
    ]

    /// Children for a given category (empty if unknown).
    static func areas(for group: String) -> [String] {
        areasByGroup[group] ?? []
    }

    /// Default category shown when a form first appears.
    static var defaultAreaGroup: String { areaGroups.first ?? "" }

    /// Default specific area for a category.
    static func defaultArea(for group: String) -> String {
        areas(for: group).first ?? ""
    }
}
