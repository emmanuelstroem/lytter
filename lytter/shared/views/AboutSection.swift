//
//  AboutSection.swift
//  lytter
//

import SwiftUI

/// About, the last section of Settings on every platform: the version, the privacy policy
/// and support pages App Store Connect asks for, and the line that says Lytter is not DR's.
///
/// The app plays DR's streams and shows DR's logos and artwork, and DR has an app of its
/// own (DR LYD). Saying plainly that this one is independent is what App Review looks for
/// under guideline 5.2, and what keeps a listener from writing to DR about it. The wording
/// is ours; if DR asks for attribution in other words, it changes here.
struct AboutSection: View {
    var body: some View {
        Section {
            LabeledContent("Version") {
                Text(verbatim: Bundle.main.versionDescription)
            }
            #if os(tvOS)
            // A row that cannot take focus is a row the list cannot scroll to.
            .focusable()
            #endif

            #if os(tvOS)
            // No browser on Apple TV, so the addresses, to open on another device.
            LabeledContent("Privacy Policy") {
                Text(verbatim: LytterLinks.privacyPolicy.displayAddress)
            }
            .focusable()
            LabeledContent("Support") {
                Text(verbatim: LytterLinks.support.displayAddress)
            }
            .focusable()
            // A row, not the footer: a footer under the last row sits past where focus can
            // scroll the list, and the remote never brings it into view.
            Text(Self.independence)
                .foregroundStyle(Color.secondary)
                .focusable()
            #else
            Link("Privacy Policy", destination: LytterLinks.privacyPolicy)
            Link("Support", destination: LytterLinks.support)
            #endif
        } header: {
            Text("About")
        } footer: {
            #if !os(tvOS)
            Text(Self.independence)
            #endif
        }
    }

    private static let independence: LocalizedStringKey =
        "Lytter is an independent app. It is not made or endorsed by DR. Programmes, logos and artwork belong to DR."
}

/// The pages behind the App Store listing, served by GitHub Pages from `site/`.
enum LytterLinks {
    static let privacyPolicy = URL(string: "https://emmanuelstroem.github.io/lytter/privacy.html")!
    static let support = URL(string: "https://emmanuelstroem.github.io/lytter/support.html")!
}

private extension URL {
    /// "emmanuelstroem.github.io/lytter/privacy.html": the address without its scheme, as
    /// someone would type it.
    var displayAddress: String {
        (host() ?? "") + path()
    }
}
