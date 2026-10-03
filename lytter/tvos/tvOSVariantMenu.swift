//
//  tvOSVariantMenu.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// A pop-over list of choices, presented over whatever is on screen.
///
/// Used by the district picker on a shelf card: a control that shows the station, and a
/// panel of its regions when clicked. Navigation is the system sidebar, not this.
///
/// Presented as a `fullScreenCover` rather than laid out in a `ZStack` beside the trigger.
/// Beside the trigger it centred on *the trigger*, so a control in the top-left corner put
/// its panel in the top-left corner, and focus could still wander into the content behind.
struct tvOSVariantMenu<Label: View, Item: Identifiable & Hashable, ItemMenu: View>: View {
    let items: [Item]
    let label: () -> Label
    let itemTitle: (Item) -> String

    /// Symbols after an item's title, for what the list knows about it — the listener's
    /// region, a favourite. The same marks the phone's sheet shows.
    var itemSymbols: (Item) -> [String] = { _ in [] }

    /// Whether an item is playing now, marked after its symbols with `PlayingMark` — not a
    /// symbol, because it moves.
    var itemIsPlaying: (Item) -> Bool = { _ in false }

    /// Hold-select on an item. The picker is where a district is named, so it is where one
    /// is pinned: the card it opened from stands for all of them.
    @ViewBuilder let itemMenu: (Item) -> ItemMenu

    let onSelect: (Item) -> Void

    /// Heading on the panel. Defaulted because this was written before it had any caller
    /// at all, and "Choose a variant" is not what a listener is doing when they pick
    /// between København and Bornholm.
    var panelTitle: String = String(localized: "Choose a variant")

    @State private var isPresented = false
    @FocusState private var focusedItemId: Item.ID?

    var body: some View {
        Button {
            isPresented = true
        } label: {
            label()
        }
        // The system's card lift. The label is artwork, so the card is the artwork.
        .buttonStyle(.card)
        .fullScreenCover(isPresented: $isPresented) {
            panel
        }
    }

    private var panel: some View {
        ZStack {
            // Dimmed rather than opaque: a panel that hides the screen entirely loses the
            // sense of having come from somewhere.
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                Text(panelTitle)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                ScrollView(.vertical) {
                    // One column, the way tvOS presents any choice between text options —
                    // Settings, audio and subtitle choices, the menus `Menu` and `Picker`
                    // produce. Grids are for browsing artwork. It was two columns to shorten
                    // the trip on the remote, which mattered less once the listener's own
                    // region was listed first and focused on open; and a column means up and
                    // down are the only directions there are.
                    LazyVStack(spacing: 16) {
                        ForEach(items) { item in
                            Button {
                                onSelect(item)
                                isPresented = false
                            } label: {
                                // Leading-aligned, with the marks trailing, like a Settings
                                // row and like the phone's district sheet.
                                HStack(spacing: 12) {
                                    Text(itemTitle(item))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)

                                    Spacer(minLength: 16)

                                    ForEach(itemSymbols(item), id: \.self) { symbol in
                                        Image(systemName: symbol)
                                            .accessibilityHidden(true)
                                    }

                                    if itemIsPlaying(item) {
                                        PlayingMark()
                                    }
                                }
                                .font(.title3)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                            }
                            // Capsules, not cards. A row inside a rounded panel is a
                            // narrower rounded shape sharing its centre — a square-cornered
                            // button in a rounded container reads as a mistake, which is
                            // why the sidebar's own rows are pills.
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            // No explicit foreground: the bordered style inverts the label
                            // on focus, and forcing white would make the focused row
                            // white-on-white.
                            .focused($focusedItemId, equals: item.id)
                            // On the button, the focusable view, or hold-select does nothing.
                            .contextMenu { itemMenu(item) }
                        }
                    }
                    // Focus scales a button up by about a tenth, and at the panel's edge
                    // that growth had nowhere to go — the pills were clipped. This is the
                    // room it needs.
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                }
            }
            .padding(48)
            // Narrower now it is one column: wide enough for "Midt & Vest" and its marks,
            // not so wide that the eye travels across empty pill to reach them.
            .frame(maxWidth: 820, maxHeight: 860)
            // A material, so the panel reads as a surface rather than as text floating on
            // the dimmed screen behind it.
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
        .onExitCommand { isPresented = false }
        .onAppear { focusedItemId = items.first?.id }
    }
}
#endif
