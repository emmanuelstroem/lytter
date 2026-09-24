//
//  SearchBar.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// The Radio tab's inline search field.
///
/// Lifted out of `ChannelView.swift` when that file was deleted — `ChannelView` and
/// `ChannelCard` were referenced by nothing, but this was, so the file was not the pure
/// orphan it looked like.
///
/// The Search tab uses the system `.searchable` presentation instead. Radio could adopt
/// it too and retire this, but that changes a screen nobody asked to have changed.
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search channels...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}
#endif
