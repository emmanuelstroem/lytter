//
//  tvOSComponents.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSChannelCard: View {
    let channel: DRChannel
    let onSelect: () -> Void
    @EnvironmentObject private var serviceManager: DRServiceManager

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                if let program = serviceManager.getCurrentProgram(for: channel),
                   let urlString = program.landscapeImageURL ?? program.primaryImageURL,
                   let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 22).fill(.gray.opacity(0.2))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [.purple.opacity(0.7), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(alignment: .center) {
                            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 72)).foregroundColor(.white)
                        }
                }

                LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 6) {
                    Text(channel.title)
                        .font(.title3).bold().foregroundColor(.white)
                        .lineLimit(1)
                    if let program = serviceManager.getCurrentProgram(for: channel) {
                        Text(program.cleanTitle())
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .padding(20)
            }
        }
        .buttonStyle(.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(radius: 12)
        .focusable(true)
        .padding(.vertical, 10)
    }
}

struct tvOSSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
            TextField("Search radios", text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button(action: { text = "" }) { Image(systemName: "xmark.circle.fill") }
            }
            Button(action: { isFocused = true }) { // focus to enable dictation via remote mic
                Image(systemName: "mic.fill")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundColor(.white)
    }
}
#endif

