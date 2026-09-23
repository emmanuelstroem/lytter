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
    /// The one app-wide DRServiceManager. Every screen, and the Siri service, share this
    /// instance. Constructing a second one is expensive: each init() loads the disk cache
    /// and then fetches the whole catalogue, and a successful fetch kicks off an unbounded
    /// preload of every image in the schedule.
    @StateObject private var serviceManager = DRServiceManager()
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
                    .environmentObject(serviceManager)
                    .environmentObject(deepLinkHandler)
                    #if os(iOS) || os(macOS)
                    .environmentObject(siriShortcutsService)
                    #endif
                    .onOpenURL { url in
                        deepLinkHandler.handleDeepLink(url)
                    }
                    .modelContainer(container)
                    .task {
                        // Hand the Siri service the shared manager rather than letting it
                        // build one of its own.
                        #if os(iOS) || os(macOS)
                        siriShortcutsService.configure(with: serviceManager)
                        #endif
                    }
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
