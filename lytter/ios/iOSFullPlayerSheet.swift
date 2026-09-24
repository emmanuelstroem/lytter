//
//  iOSFullPlayerSheet.swift
//  lytter
//
//  Created by Emmanuel on 08/08/2025.
//

import SwiftUI
import os

#if os(iOS)
struct iOSFullPlayerSheet: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @Environment(\.dismiss) private var dismiss
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 100
    @State private var volume: Double = 0.7
    @State private var showingDescriptionSheet: Bool = false
    @State private var showingScheduleSheet: Bool = false
    
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
        NavigationView {
            ZStack {
                // Semantic background, so the player follows the system appearance.
                // In dark mode systemBackground is black, which is very close to the
                // hardcoded gradient this replaces; in light mode it is white. Everything
                // drawn on top uses .primary/.secondary rather than fixed white and grey.
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if let currentChannel = currentChannel {
                    VStack(spacing: 0) {
                        // Top VStack - Artwork Component
                        VStack {
                            PlayerArtworkView(
                                channel: currentChannel,
                                currentProgram: serviceManager.getCurrentProgram(for: currentChannel),
                                channelColor: channelColor,
                                channelIcon: channelIcon
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Bottom VStack - All other components
                        VStack(spacing: 30) {
                            // Info Component
                            // The share control lives inside PlayerInfoView.
                            PlayerInfoView(
                                title: infoTitle,
                                subtitle: infoSubtitle,
                                channel: currentChannel,
                                serviceManager: serviceManager
                            )
                            
                            // Progress Bar with centered LIVE text and transparency fade
                            VStack(spacing: 8) {
                                GeometryReader { geometry in
                                    ZStack {
                                        ProgressView(value: currentTime, total: totalTime)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                            .scaleEffect(y: 2)
                                            // A mask reads only the alpha channel, so
                                            // the black here is not a colour choice and
                                            // does not need to follow the appearance.
                                            .mask(
                                                RadialGradient(
                                                    colors: [
                                                        Color.black.opacity(0.0),
                                                        Color.black.opacity(0.5),
                                                        Color.black.opacity(1.0)
                                                    ],
                                                    center: .center,
                                                    startRadius: 0,
                                                    endRadius: geometry.size.width * 0.5 // 3/4 of half width
                                                )
                                            )
                                        
                                        Text("LIVE")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                .frame(height: 20) // Fixed height for the progress view
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer()
                            
                            // Controls Component
                            //
                            // No skip buttons: these are live ICY streams with no
                            // seekable range, so back-30 and forward did nothing at all.
                            // The same buttons were removed from the lock screen and
                            // Control Centre for the same reason.
                            PlayerControlsView(
                                isPlaying: serviceManager.isPlaying,
                                showBackwardButton: false,
                                showForwardButton: false,
                                onPlayPauseTap: {
                                    if let playingChannel = serviceManager.playingChannel {
                                        serviceManager.togglePlayback(for: playingChannel)
                                    }
                                }
                            )
                            
                            Spacer()
                            
                            // // Volume Component
                            // PlayerVolumeView(
                            //     volume: $volume
                            // ) { newVolume in
                            //     // Handle volume change
                            //     print("Volume changed to: \(newVolume)")
                            // }
                            
                            // Actions Component
                            PlayerActionsView(
                                onQuoteTap: {
                                    showingDescriptionSheet = true
                                },
                                onListTap: {
                                    showingScheduleSheet = true
                                }
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.top, 40)
                } else {
                    // No channel playing
                    VStack(spacing: 20) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 64, weight: .medium))
                            .foregroundStyle(Color.secondary)
                        
                        Text("No Channel Playing")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .overlay(alignment: .top) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .sheet(isPresented: $showingScheduleSheet) {
                if let currentChannel {
                    iOSChannelScheduleSheet(channel: currentChannel,
                                            serviceManager: serviceManager)
                }
            }
            .sheet(isPresented: $showingDescriptionSheet) {
                if let currentChannel = currentChannel {
                    iOSProgramDescriptionSheet(
                        channel: currentChannel,
                        currentProgram: serviceManager.getCurrentProgram(for: currentChannel),
                        programDescription: programDescription
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }
}

/// Programme details, presented from the full player.
///
/// Typography follows the HIG's text-style hierarchy rather than fixed sizes, so it
/// scales with Dynamic Type. Metadata uses `Label`, which pairs a symbol with its text
/// and keeps the two optically matched — the previous version placed a default-size
/// `Image` beside body text, and the symbols read as oversized next to it.
struct iOSProgramDescriptionSheet: View {
    let channel: DRChannel?
    let currentProgram: DREpisode?
    let programDescription: String
    @Environment(\.dismiss) private var dismiss

    private var airingTime: String? {
        guard let start = currentProgram?.startDate, let end = currentProgram?.endDate
        else { return nil }
        return "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String? {
        guard let duration = currentProgram?.duration, duration > 0 else { return nil }
        // Localised by the formatter rather than hand-built with "min"/"mins".
        return Duration.seconds(duration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let title = currentProgram?.cleanTitle(), !title.isEmpty {
                        Text(title)
                            .font(.title3.weight(.semibold))
                    }

                    if let airingTime {
                        Text(airingTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Duration and categories. `.imageScale(.small)` is what brings the
                    // symbols down to the weight of the text beside them.
                    let categories = currentProgram?.categories ?? []
                    if durationText != nil || !categories.isEmpty {
                        HStack(spacing: 16) {
                            if let durationText {
                                Label(durationText, systemImage: "clock")
                            }
                            if let category = categories.first {
                                Label(category, systemImage: "tag")
                            }
                        }
                        .font(.subheadline)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    }

                    Divider()

                    // .primary, not .secondary. As secondary this was legible in light
                    // mode and close to invisible against the sheet in dark mode.
                    Text(programDescription)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(channel?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    iOSFullPlayerSheet(serviceManager: DRServiceManager(), selectionState: SelectionState())
}
#endif
