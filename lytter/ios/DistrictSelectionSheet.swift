import SwiftUI

#if os(iOS)
// MARK: - District Selection Sheet
struct DistrictSelectionSheet: View {
    let groupedChannel: GroupedChannel
    let onChannelSelect: (DRChannel) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            if #available(iOS 26.0, *) {
                VStack(spacing: 16) {
                    ForEach(groupedChannel.channels, id: \.id) { channel in
                        Button(action: {
                            onChannelSelect(channel)
                            dismiss()
                        }) {
                            Text(channel.district ?? channel.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.glass) // shows background on buttons
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            } else {
                // Fallback on earlier versions
                VStack(spacing: 16) {
                    ForEach(groupedChannel.channels, id: \.id) { channel in
                        VStack {
                            Text(channel.district ?? channel.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground).opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .onTapGesture {
                            onChannelSelect(channel)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
} 
#endif
