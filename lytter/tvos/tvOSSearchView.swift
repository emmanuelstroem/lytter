//
//  tvOSSearchView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSSearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @State private var query: String = ""

    private var results: [DRChannel] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return serviceManager.availableChannels }
        return serviceManager.availableChannels.filter { ch in
            ch.displayName.localizedCaseInsensitiveContains(query) ||
            ch.slug.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.title < $1.title }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: [.black, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 24) {
                        Text("Search")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        tvOSSearchField(text: $query)
                            .frame(width: min(geometry.size.width * 0.45, 800))
                    }

                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 320), spacing: 40), count: 3), spacing: 40) {
                            ForEach(results, id: \.id) { channel in
                                Button {
                                    serviceManager.playChannel(channel)
                                    selectionState.selectChannel(channel)
                                } label: {
                                    tvOSChannelCard(channel: channel)
                                        .frame(height: 260)
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()
                            }
                        }
                        .padding(.trailing, 60)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 60)
            }
        }
        .onAppear { if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() } }
    }
}
#endif

