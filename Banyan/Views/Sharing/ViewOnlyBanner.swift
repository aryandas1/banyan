// ViewOnlyBanner.swift
// A thin banner shown atop a shared tree so a viewer always knows they're looking
// at someone else's tree in read-only mode.

import SwiftUI

struct ViewOnlyBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
            Text("View only")
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.secondary)
    }
}

#Preview {
    ViewOnlyBanner()
}
