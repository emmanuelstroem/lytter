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
struct tvOSVariantMenu<Label: View, Item: Identifiable & Hashable>: View {
    let items: [Item]
    let label: () -> Label
    let itemTitle: (Item) -> String
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
        // Scales without drawing a container, so a caller can put a caption inside the label
        // and have it lift with the artwork instead of being boxed in with it.
        .buttonStyle(tvOSMusicCardButtonStyle())
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
                    // Two columns keep focus movement predictable — a single tall column of
                    // ten districts is a long way to travel on a remote.
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                              spacing: 24) {
                        ForEach(items) { item in
                            Button {
                                onSelect(item)
                                isPresented = false
                            } label: {
                                Text(itemTitle(item))
                                    .font(.title3)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity)
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
                        }
                    }
                    // Focus scales a button up by about a tenth, and at the panel's edge
                    // that growth had nowhere to go — the leftmost and rightmost pills were
                    // clipped. This is the room it needs.
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                }
            }
            .padding(48)
            .frame(maxWidth: 1100, maxHeight: 760)
            // A material, so the panel reads as a surface rather than as text floating on
            // the dimmed screen behind it.
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
        .onExitCommand { isPresented = false }
        .onAppear { focusedItemId = items.first?.id }
    }
}
#endif
