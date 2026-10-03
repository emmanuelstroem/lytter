//
//  ShortcutsView.swift
//  ios
//
//  Created by Emmanuel on 27/01/2025.
//

import SwiftUI
import Intents
import IntentsUI
import os

#if os(iOS)
struct ShortcutsView: View {
    @EnvironmentObject var siriShortcutsService: SiriShortcutsService
    /// Shared with the rest of the app. This used to be its own @StateObject, which meant
    /// opening this tab started a second catalogue fetch and image preload, and showed a
    /// channel list that drifted from the one every other screen was using.
    @EnvironmentObject var serviceManager: DRServiceManager
    @State private var showingAddShortcut = false
    @State private var selectedChannel: DRChannel?
    
    /// Pushed from Settings, so it brings no `NavigationStack` of its own — it was a tab,
    /// and a stack inside a stack draws two navigation bars.
    var body: some View {
        List {
            Section(header: Text("Siri Shortcuts")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice Commands")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Say \"Hey Siri, play [channel name]\" to start listening to your favorite DR radio channels.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add All Channels to Siri") {
                        addAllChannelsToSiri()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Available Channels")) {
                ForEach(serviceManager.availableChannels, id: \.id) { channel in
                    ChannelShortcutRow(channel: channel)
                }
            }
            
            Section(header: Text("Quick Actions"), footer: Text("These shortcuts will be available in the Shortcuts app and can be triggered by Siri.")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shortcuts App Integration")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Create custom shortcuts in the Shortcuts app to automate your radio listening experience.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Open Shortcuts App") {
                        openShortcutsApp()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Asked for here, where Siri is what the listener has come to set up.
            INPreferences.requestSiriAuthorization { status in
                Log.siri.debug("authorization status \(status.rawValue, privacy: .public)")
            }
            siriShortcutsService.refreshShortcuts()
        }
    }
    
    private func addAllChannelsToSiri() {
        siriShortcutsService.donateAllChannelShortcuts()
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func openShortcutsApp() {
        if let shortcutsURL = URL(string: "shortcuts://") {
            if UIApplication.shared.canOpenURL(shortcutsURL) {
                UIApplication.shared.open(shortcutsURL)
            } else {
                // Fallback to App Store
                if let appStoreURL = URL(string: "https://apps.apple.com/app/shortcuts/id915249334") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
        }
    }
}

struct ChannelShortcutRow: View {
    let channel: DRChannel
    @EnvironmentObject var siriShortcutsService: SiriShortcutsService
    @State private var showingShortcutView = false
    
    var body: some View {
        HStack {
            // Channel icon/color
            Circle()
                .fill(channelColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(channel.title.prefix(2))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Say \"Hey Siri, play \(channel.title)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Add") {
                showingShortcutView = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingShortcutView) {
            ShortcutConfigurationView(channel: channel)
        }
    }
    
    private var channelColor: Color { channel.stationColor }
}

struct ShortcutConfigurationView: View {
    let channel: DRChannel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var siriShortcutsService: SiriShortcutsService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Channel info
                VStack(spacing: 16) {
                    Circle()
                        .fill(channelColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(channel.title.prefix(2))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Text(channel.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configure Siri Shortcut")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Shortcut configuration
                VStack(spacing: 16) {
                    Text("Voice Command")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Say \"Hey Siri, play \(channel.title)\"")
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("This will automatically start playing \(channel.title) when triggered.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Add to Siri") {
                        addToSiri()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .navigationTitle("Configure Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var channelColor: Color { channel.stationColor }
    
    private func addToSiri() {
        siriShortcutsService.donateShortcut(for: channel)
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dismiss()
    }
}

#Preview {
    NavigationStack { ShortcutsView() }
        .environmentObject(SiriShortcutsService.shared)
        .environmentObject(DRServiceManager())
}

#endif
