//
//  SKView+Modifiers.swift
//  Skarnik
//
//  Created by Logout on 10.11.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import SwiftUI

extension Color {
    static let appBackground = Color("BackgroundColor")
}

extension View {
    /// Tab bar background stays visible even when the content is scrolled to the top.
    func opaqueTabBar() -> some View {
        toolbarBackground(.visible, for: .tabBar)
    }

    /// Hides the list's own background so the app background shows through.
    func appListBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.appBackground)
    }

    /// Extra vertical row padding on Mac Catalyst; no change elsewhere.
    @ViewBuilder
    func catalystVerticalPadding() -> some View {
#if targetEnvironment(macCatalyst)
        padding(.vertical)
#else
        self
#endif
    }
}
