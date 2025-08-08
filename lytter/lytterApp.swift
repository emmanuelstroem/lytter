//
//  lytterApp.swift
//  lytter
//
//  Created by Emmanuel on 07/08/2025.
//

import SwiftUI
import SwiftData

@main
struct lytterApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    
    #if os(iOS) || os(macOS)
    @StateObject private var siriShortcutsService = SiriShortcutsService.shared
    #endif
    
    @State private var sharedModelContainer: ModelContainer? = nil
    @State private var modelContainerError: String? = nil
    
    private func initializeModelContainer() {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            modelContainerError = "Failed to initialize app data. Please close and restart the app. If the issue persists, contact support.\n\nError details: \(error.localizedDescription)"
            sharedModelContainer = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = modelContainerError {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("App Error")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(error)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding(40)
            } else if let container = sharedModelContainer {
                ContentView()
                    .environmentObject(deepLinkHandler)
                    #if os(iOS) || os(macOS)
                    .environmentObject(siriShortcutsService)
                    #endif
                    .onOpenURL { url in
                        deepLinkHandler.handleDeepLink(url)
                    }
                    .modelContainer(container)
                    .task {
                        if sharedModelContainer == nil && modelContainerError == nil {
                            initializeModelContainer()
                        }
                    }
            } else {
                ProgressView("Starting app...")
                    .task {
                        if sharedModelContainer == nil && modelContainerError == nil {
                            initializeModelContainer()
                        }
                    }
            }
        }
    }
}
