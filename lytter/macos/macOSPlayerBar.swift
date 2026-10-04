//
//  macOSPlayerBar.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// The bar docked to the bottom of the window — what Music.app calls its "LCD": artwork,
/// what's playing, transport, volume, AirPlay. Full-width and always present, not a
/// floating capsule that appears only while something plays; a window has room a phone
/// does not; and a) is where Mac Music actually puts it.
struct macOSPlayerBar: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                artwork
                info
                Spacer(minLength: 12)
                transport
                Spacer(minLength: 12)
                share
                AirPlayButtonView(size: 20, tint: .secondaryLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var artwork: some View {
        if let channel = serviceManager.playingChannel {
            Button {
                selectionState.isShowingFullPlayer = true
            } label: {
                CachedAsyncImage(url: serviceManager.artworkURL(for: channel),
                                 maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    StationArtworkPlaceholder(channel: channel)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .tertiarySystemFill))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private var info: some View {
        if let channel = serviceManager.playingChannel {
            VStack(alignment: .leading, spacing: 1) {
                Text(channel.qualifiedName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                // A problem that stops audio takes the programme's line: the bar is the
                // one place on the Mac that is always in view.
                if let problem = serviceManager.connectionProblem, problem.affectsPlayback {
                    Label(problem.title, systemImage: problem.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(serviceManager.getCurrentProgram(for: channel)?.programmeName
                         ?? String(localized: "Live"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 260, alignment: .leading)
        } else {
            Text("Nothing Playing")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// Share, with SharePlay in its menu — the way Music offers it on the Mac. The bar,
    /// because it is the one place on the Mac that is always in view while something plays.
    @ViewBuilder
    private var share: some View {
        if let channel = serviceManager.playingChannel {
            ShareLink(
                item: SharedChannel(
                    activity: RadioShareActivity(channel: channel),
                    text: "\(channel.qualifiedName)\n\(DeepLinkHandler.generateDeepLinkString(for: channel))"),
                preview: SharePreview(channel.qualifiedName)
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondary)
            .help("Share")
            .accessibilityLabel("Share")
        }
    }

    @ViewBuilder
    private var transport: some View {
        if let channel = serviceManager.playingChannel {
            Button {
                serviceManager.togglePlayback(for: channel)
            } label: {
                Image(systemName: serviceManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
    }
}
#endif
