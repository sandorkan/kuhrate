//
//  OnboardingView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.01.2026.
//

import SwiftUI
import CoreData

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Capture Everything That Matters",
            description: "Jot down insights from books, podcasts, videos, and conversations. Don't worry about organizing yet.",
            imageName: "onboarding-capture"
        ),
        OnboardingPage(
            title: "Keep Only What's Valuable",
            description: "Review your notes monthly and yearly. The best insights naturally rise to your Evergreen collection.",
            imageName: "onboarding-curate"
        ),
        OnboardingPage(
            title: "Stay on Track Effortlessly",
            description: "Kuhrate reminds you when it's time to review. No complex schedules—just simple, regular reflection.",
            imageName: "onboarding-remind"
        )
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip Button (only on first two screens)
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    } else {
                        Spacer().frame(height: 50)
                    }
                }

                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Progress Dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)

                // Next / Get Started Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")

        // Request notification permission
        NotificationManager.shared.requestPermission { granted in
            if granted {
                print("✅ Notifications authorized")
                // Schedule notifications after permission granted
                let context = PersistenceController.shared.container.viewContext
                NotificationManager.shared.scheduleAllNotifications(context: context)
            } else {
                print("⚠️ Notifications denied")
            }
        }

        withAnimation {
            showOnboarding = false
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Illustration
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .padding(.horizontal, 40)

            Spacer()

            // Title
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Description
            Text(page.description)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
}

// MARK: - Preview

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
