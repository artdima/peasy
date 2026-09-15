import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case panel
    case menuBar
    case icloud

    static let storageKey = "settingsTab"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .panel: String(localized: "Panel")
        case .menuBar: String(localized: "Menu bar")
        case .icloud: String(localized: "iCloud")
        }
    }

    @ViewBuilder
    var icon: some View {
        switch self {
        case .general:
            Glyph(kind: .sliders, size: 20)
        case .panel:
            Glyph(kind: .sidebar, size: 20)
        case .menuBar:
            Glyph(kind: .menuBarTab, size: 20)
        case .icloud:
            Glyph(kind: .cloudTab, size: 20)
        }
    }
}

struct SettingsTabBar: View {
    @Binding var selection: SettingsTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(tab: tab, isSelected: selection == tab) {
                        withAnimation(.easeOut(duration: 0.22)) {
                            selection = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(SettingsStyle.tabBarShade)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SettingsStyle.tabBarHighlight)
                .frame(height: 1)
                .offset(y: 1)
        }
        .zIndex(1)
    }
}

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                tab.icon
                    .foregroundStyle(isSelected ? PanelStyle.green : PanelStyle.secondary)
                FittedText(string: tab.title, size: 11, weight: .medium)
                    .foregroundStyle(isSelected || isHovered ? PanelStyle.primary : PanelStyle.secondary)
            }
            .frame(width: 76, height: 52)
            .background(isSelected ? SettingsStyle.tabSelected : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityLabel(Text(verbatim: tab.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
