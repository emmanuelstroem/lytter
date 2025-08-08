//
//  FullPlayer.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

// MARK: - Full Player Sheet
struct FullPlayerSheet: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @Environment(\.dismiss) private var dismiss
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 100
    @State private var volume: Double = 0.7
    @State private var showingDescriptionSheet: Bool = false // New state for description sheet
    
    // Get the current playing channel from serviceManager
    private var currentChannel: DRChannel? {
        serviceManager.playingChannel
    }
    
    private var channelColor: Color {
        guard let currentChannel = currentChannel else { return .purple }
        let hash = abs(currentChannel.id.hashValue)
        let hue = Double(hash % 360) / 360.0
        let saturation = 0.7 + Double(hash % 20) / 100.0
        let brightness = 0.8 + Double(hash % 20) / 100.0
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    private var channelIcon: String {
        guard let currentChannel = currentChannel else {
            return "antenna.radiowaves.left.and.right"
        }
        
        // Get the current program and use its category-based icon
        if let currentProgram = serviceManager.getCurrentProgram(for: currentChannel) {
            return currentProgram.categoryIcon
        }
        
        // Fallback to default radio icon if no current program
        return "antenna.radiowaves.left.and.right"
    }
    
    private var infoTitle: String {
        guard let currentChannel = currentChannel else { return "No Channel" }
        
        if let track = serviceManager.currentTrack, track.isCurrentlyPlaying {
            let programTitle = serviceManager.getCurrentProgram(for: currentChannel)?.cleanTitle() ?? "Live"
            return "\(currentChannel.title) - \(programTitle)"
        } else {
            return currentChannel.title
        }
    }
    
    private var infoSubtitle: String {
        guard let currentChannel = currentChannel else { return "No program information" }
        
        if let track = serviceManager.currentTrack, track.isCurrentlyPlaying {
            return track.displayText
        } else if let currentProgram = serviceManager.getCurrentProgram(for: currentChannel) {
            return currentProgram.cleanTitle()
        } else {
            return "Live"
        }
    }
    
    private var programDescription: String {
        guard let currentChannel = currentChannel else { return "No program information available" }
        
        if let currentProgram = serviceManager.getCurrentProgram(for: currentChannel) {
            return currentProgram.description ?? "Live radio programming"
        } else {
            return "Live radio programming"
        }
    }
    
    var body: some View {
        #if os(iOS)
        iOSFullPlayerSheet(serviceManager: serviceManager, selectionState: selectionState)
        #endif
    }
}

// MARK: - Program Description Sheet
struct ProgramDescriptionSheet: View {
    let channel: DRChannel?
    let currentProgram: DREpisode?
    let programDescription: String
    @Environment(\.dismiss) private var dismiss
    
    private var navigationTitle: String {
        var title = channel?.title ?? "Unknown Channel"
        if let currentProgram = currentProgram {
            title += " - \(currentProgram.cleanTitle())"
        }
        return title
    }
    
    var body: some View {
        #if os(iOS) || os(macOS)
        iOSFullPlayerSheet(
            serviceManager: DRServiceManager(),
            selectionState: SelectionState()
        )
        #endif
    }
}

#Preview {
    FullPlayerSheet(
        serviceManager: DRServiceManager(),
        selectionState: SelectionState()
    )
} 
