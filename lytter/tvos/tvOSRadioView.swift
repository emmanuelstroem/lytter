//
//  tvOSRadioView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSRadioView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState

    private var groupedChannels: [(name: String, channels: [DRChannel])] {
        let channels = serviceManager.availableChannels
        let grouped = Dictionary(grouping: channels) { $0.name }
        let groups = grouped.map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
        return groups.map { (name: $0.key, channels: $0.value) }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: [.black, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    Text("Radio")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    if serviceManager.isLoading {
                        ProgressView().scaleEffect(1.4).tint(.white)
                    } else if let error = serviceManager.error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 60)).foregroundColor(.orange)
                            Text(error).foregroundColor(.white)
                            Button("Retry") { serviceManager.loadChannels() }
                        }
                    } else if groupedChannels.isEmpty {
                        Text("No channels").foregroundColor(.white)
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(alignment: .leading, spacing: 40) {
                                ForEach(groupedChannels, id: \.name) { group in
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text(group.name)
                                            .font(.title2)
                                            .foregroundColor(.white)

                                        ScrollView(.horizontal) {
                                            LazyHGrid(rows: [GridItem(.fixed(300))], spacing: 40) {
                                                ForEach(group.channels, id: \.id) { channel in
                                                    tvOSChannelCard(channel: channel) {
                                                        serviceManager.playChannel(channel)
                                                        selectionState.selectChannel(channel)
                                                    }
                                                    .frame(width: 460, height: 300)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                        }
                                    }
                                }
                            }
                            .padding(.trailing, 60)
                        }
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 60)
            }
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }
}
#endif

