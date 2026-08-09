// ViewOnlyBanner.swift
// A thin banner shown atop a shared tree so a viewer always knows they're looking
// at someone else's tree in read-only mode. The accessible text stays exactly
// "View only" — ViewerModeUITests asserts on it.

import SwiftUI

struct ViewOnlyBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.fill")
                .font(.subheadline)
            Text("View only")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: BanyanTheme.TapTarget.minimum)
        .background(BanyanTheme.Color.primary)
    }
}

#Preview {
    ViewOnlyBanner()
}
