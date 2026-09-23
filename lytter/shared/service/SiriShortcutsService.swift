//
//  SiriShortcutsService.swift
//  ios
//
//  Created by Emmanuel on 27/01/2025.
//

import Foundation
import Intents
import IntentsUI
import Combine

// MARK: - Siri Shortcuts Service


class SiriShortcutsService: ObservableObject {
    static let shared = SiriShortcutsService()
    
    #if os(iOS) || os(macOS)
    @Published var availableShortcuts: [INShortcut] = []
    #endif
    /// The app-wide manager, handed over by lytterApp at launch.
    ///
    /// Held weakly: this is a singleton that outlives any individual scene and it does not
    /// own the manager. It previously built its own DRServiceManager on first use, which
    /// meant a second catalogue fetch plus a second full image preload, against a channel
    /// list no screen ever saw.
    private weak var serviceManager: DRServiceManager?

    private init() {}

    /// Supplies the shared DRServiceManager. Safe to call repeatedly.
    func configure(with serviceManager: DRServiceManager) {
        self.serviceManager = serviceManager
    }

    // MARK: - Shortcut Management
    
    func updateAvailableShortcuts() {
        #if os(iOS) || os(macOS)
        let shortcuts = createChannelShortcuts()
        availableShortcuts = shortcuts
        #endif
    }
    
    func refreshShortcuts() {
        // Wait a bit for channels to load, then update shortcuts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            #if os(iOS) || os(macOS)
            self.updateAvailableShortcuts()
            #endif
        }
    }
    
    private func createChannelShortcuts() -> [INShortcut] {
        guard let serviceManager else { return [] }
        let channels = serviceManager.availableChannels

        return channels.map { channel in
            let activity = createUserActivity(for: channel)
            return INShortcut(userActivity: activity)
        }
    }
    
    // MARK: - Shortcut Creation
    
    func createShortcut(for channel: DRChannel) -> INShortcut? {
        let activity = createUserActivity(for: channel)
        return INShortcut(userActivity: activity)
    }
    
    // MARK: - Shortcut Invocation
    
    func handleShortcutInvocation(channelId: String) {
        guard let serviceManager else {
            print("SiriShortcutsService has no service manager; ignoring shortcut for \(channelId)")
            return
        }
        guard let channel = serviceManager.availableChannels.first(where: { $0.id == channelId }) else {
            print("Channel not found for ID: \(channelId)")
            return
        }

        // Play the channel
        serviceManager.playChannel(channel)
    }
    
    // MARK: - Siri Integration
    
    func donateShortcut(for channel: DRChannel) {
        donateUserActivity(for: channel)
    }
    
    func donateAllChannelShortcuts() {
        donateAllUserActivities()
    }
    
    // MARK: - Shortcut Suggestions
    
    func suggestShortcuts() {
        donateAllUserActivities()
    }
}

// MARK: - User Activity Based Shortcuts

extension SiriShortcutsService {
    
    func createUserActivity(for channel: DRChannel) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "PlayChannelActivity")
        activity.title = "Play \(channel.title)"
        activity.suggestedInvocationPhrase = "Play \(channel.title)"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.isEligibleForHandoff = true
        
        // Add channel information to user info
        activity.userInfo = [
            "channelId": channel.id,
            "channelName": channel.title,
            "channelSlug": channel.slug
        ]
        
        return activity
    }
    
    func handleUserActivity(_ activity: NSUserActivity) {
        guard activity.activityType == "PlayChannelActivity",
              let channelId = activity.userInfo?["channelId"] as? String else {
            return
        }
        
        handleShortcutInvocation(channelId: channelId)
    }
    
    func donateUserActivity(for channel: DRChannel) {
        let activity = createUserActivity(for: channel)
        activity.becomeCurrent()
    }
    
    func donateAllUserActivities() {
        guard let serviceManager else { return }

        for channel in serviceManager.availableChannels {
            donateUserActivity(for: channel)
        }
    }
} 

