//
//  iOSSleepTimerSheet.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// Picks when playback should stop.
///
/// "End of programme" is offered because it is the one a listener actually wants on live
/// radio — finish this, then stop — and the schedule needed to compute it is already
/// loaded. It is hidden when the channel has no schedule rather than shown and failing.
struct iOSSleepTimerSheet: View {
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss

    private static let durations = [15, 30, 45, 60]

    private var programmeEnd: Date? {
        guard let channel = serviceManager.playingChannel,
              let end = serviceManager.getCurrentProgram(for: channel)?.endDate,
              end > Date() else { return nil }
        return end
    }

    var body: some View {
        NavigationStack {
            List {
                if let timer = serviceManager.sleepTimer {
                    Section {
                        LabeledContent {
                            Text(timer.firesAt, style: .timer)
                                .monospacedDigit()
                                .foregroundStyle(Color.accentColor)
                        } label: {
                            Label("Stopping", systemImage: "moon.zzz.fill")
                        }

                        Button("Turn off", role: .destructive) {
                            serviceManager.cancelSleepTimer()
                            dismiss()
                        }
                    }
                }

                Section {
                    ForEach(Self.durations, id: \.self) { minutes in
                        Button {
                            serviceManager.startSleepTimer(.after(minutes: minutes))
                            dismiss()
                        } label: {
                            row(title: "\(minutes) minutes",
                                isSelected: serviceManager.sleepTimer?.mode == .after(minutes: minutes))
                        }
                    }

                    if let programmeEnd {
                        Button {
                            serviceManager.startSleepTimer(.endOfProgramme)
                            dismiss()
                        } label: {
                            row(title: String(localized: "End of programme"),
                                detail: programmeEnd.formatted(date: .omitted, time: .shortened),
                                isSelected: serviceManager.sleepTimer?.mode == .endOfProgramme)
                        }
                    }
                } footer: {
                    Text("Playback fades out before it stops.")
                }
            }
            .navigationTitle("Sleep timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func row(title: String, detail: String? = nil, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.primary)
            if let detail {
                Text(detail)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
#endif
