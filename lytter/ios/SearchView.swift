//
//  SearchView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS)
// MARK: - Search View
struct SearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
                
                Text("Search functionality coming soon...")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                
                Spacer()
            }
            .padding(.top, 60)
        }
    }
} 
#endif
