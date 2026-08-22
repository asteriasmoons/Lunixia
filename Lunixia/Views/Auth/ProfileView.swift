//
//  ProfileView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query private var users: [AuthUser]
    @Query private var profiles: [LunixiaPointsProfile]
    @Query private var tarotRecords: [DailyTarotRecord]
    @Query private var tarotPullRecords: [TarotPullRecord]
    @Query private var lenormandRecords: [DailyLenormandRecord]
    @Query private var lenormandPullRecords: [LenormandPullRecord]

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var showSpiritualEraseConfirmation = false

    private var user: AuthUser? { users.first }
    private var currentPoints: Int { profiles.first?.currentPoints ?? 0 }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Nav
                HStack(spacing: 12) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    // Self-care points chip
                    HStack(spacing: 5) {
                        Image("heartfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                            .foregroundStyle(pinkGradient)
                        Text("\(currentPoints)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(pinkGradient)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.pink.opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color.pink.opacity(0.35), lineWidth: 0.75))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {

                        // MARK: Photo + name card
                        GlassCard(padding: 24) {
                            VStack(spacing: 16) {

                                // Circle photo picker
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    ZStack {
                                        Circle()
                                            .fill(LColors.glassSurface2)
                                            .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                            .frame(width: 96, height: 96)

                                        if let img = profileImage {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 96, height: 96)
                                                .clipShape(Circle())
                                        } else {
                                            Image("profilewavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 44, height: 44)
                                                .foregroundStyle(LGradients.header)
                                        }

                                        // Camera badge
                                        Circle()
                                            .fill(LColors.glassSurface)
                                            .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 0.75))
                                            .frame(width: 26, height: 26)
                                            .overlay(
                                                Image("addwavy")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 12, height: 12)
                                                    .foregroundStyle(LGradients.header)
                                            )
                                            .offset(x: 32, y: 32)
                                    }
                                }
                                .buttonStyle(.plain)
                                .onChange(of: pickerItem) { loadPhoto() }

                                VStack(spacing: 4) {
                                    Text(user?.displayName ?? "Your Name")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)

                                    if let email = user?.email {
                                        Text(email)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)

                        #if DEBUG
                        if isSpiritualResetAdmin {
                        Button {
                            eraseTodaysSpiritualRecords()
                            showSpiritualEraseConfirmation = true
                        } label: {
                            GlassCard(padding: 18) {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(LGradients.header)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Erase Today’s Tarot + Lenormand")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                        Text("Developer-only reset button")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        }

                        Button {
                            storeManager.toggleAdminPremiumOverride()
                        } label: {
                            GlassCard(padding: 18) {
                                HStack(spacing: 10) {
                                    Image("heartlock")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Admin Premium Override")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)

                                        Text(storeManager.adminPremiumOverrideEnabled ? "Premium override is ON" : "Premium override is OFF")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    Spacer()

                                    Text(storeManager.adminPremiumOverrideEnabled ? "ON" : "OFF")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(storeManager.adminPremiumOverrideEnabled ? LColors.accentGradient : LinearGradient(colors: [LColors.textSecondary.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        #endif

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .onAppear { loadSavedPhoto() }
        .alert("Spiritual Data Erased", isPresented: $showSpiritualEraseConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Today’s Tarot and Lenormand records have been removed.")
        }
    }

    private let debugAppleUserID = "001664.f2fefbb84f024544b98e865fa6c6b49e.1524"

    private var isSpiritualResetAdmin: Bool {
        user?.appleUserId == debugAppleUserID
    }

    private func eraseTodaysSpiritualRecords() {
        guard isSpiritualResetAdmin else { return }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        for record in tarotRecords where record.createdAt >= todayStart && record.createdAt < tomorrowStart {
            modelContext.delete(record)
        }

        for record in lenormandRecords where record.createdAt >= todayStart && record.createdAt < tomorrowStart {
            modelContext.delete(record)
        }

        for record in tarotPullRecords where record.pulledAt >= todayStart && record.pulledAt < tomorrowStart {
            modelContext.delete(record)
        }

        for record in lenormandPullRecords where record.pulledAt >= todayStart && record.pulledAt < tomorrowStart {
            modelContext.delete(record)
        }

        try? modelContext.save()
    }

    // MARK: - Photo handling

    private func loadPhoto() {
        Task {
            guard let item = pickerItem,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else { return }
            await MainActor.run {
                profileImage = img
                savePhoto(img)
            }
        }
    }

    private func savePhoto(_ img: UIImage) {
        guard let data = img.jpegData(compressionQuality: 0.85) else { return }
        let url = photoURL()
        try? data.write(to: url)
        users.first?.profileImagePath = url.path
        try? modelContext.save()
    }

    private func loadSavedPhoto() {
        let url = photoURL()
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            profileImage = img
        }
    }

    private func photoURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lunixia_profile_photo.jpg")
    }
}

// MARK: - Pink gradient

private let pinkGradient = LinearGradient(
    colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 1.0, green: 0.2, blue: 0.5)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
