import SwiftUI

struct SettingsView: View {
    let sync: SyncMonitor
    var onTitleChange: (String) -> Void = { _ in }
    @AppStorage(SettingsTab.storageKey) private var tab = SettingsTab.general
    @AppStorage(PanelLayout.storageKey) private var layout = PanelLayout.vertical
    @AppStorage(PanelSettings.expandsOnHoverKey) private var expandsOnHover = true
    @AppStorage(PanelSettings.multilineTasksKey) private var multilineTasks = false
    @AppStorage(PanelSettings.showsTodayIndicatorKey) private var showsIndicator = true
    @AppStorage(PanelSettings.showsBuddyKey) private var showsBuddy = true
    @AppStorage(DisplayPreference.storageKey) private var display = DisplayPreference.builtIn
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $tab)
            pane
                .id(tab)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 4)), removal: .identity))
        }
        .padding(.top, 34)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#1E1E20"))
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onChange(of: tab, initial: true) { _, tab in
            onTitleChange(tab.title)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    private var pane: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch tab {
            case .general: generalPane
            case .panel: panelPane
            case .notch: notchPane
            case .icloud: SyncSection(sync: sync)
            }
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 24, trailing: 24))
    }

    private var generalPane: some View {
        SettingsCard {
            SettingsRow(minHeight: 44) {
                Text("Quick new task")
                    .settingsTitle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                ShortcutRecorder()
            }
            SettingsToggleRow(
                title: "Open at login",
                subtitle: launchAtLogin.needsApproval ? "Allow Peasy in Login Items to finish." : nil,
                isOn: Binding(get: { launchAtLogin.isOn }, set: { launchAtLogin.set($0) }),
                minHeight: 44,
                separated: true
            )
            if let message = launchAtLogin.errorMessage {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
        }
    }

    private var panelPane: some View {
        SettingsCard {
            HStack(alignment: .top, spacing: 14) {
                LayoutOption(layout: .vertical, title: "Vertical", subtitle: "Projects in a column on the left", selection: $layout)
                LayoutOption(layout: .horizontal, title: "Horizontal", subtitle: "Projects as tabs on top", selection: $layout)
            }
            .padding(14)
            SettingsToggleRow(title: "Multiline tasks", subtitle: "Long titles wrap onto new lines", isOn: $multilineTasks, separated: true)
        }
    }

    private var notchPane: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "Expand on hover",
                subtitle: expandsOnHover ? "The panel opens when the pointer is over the notch" : "The panel opens when you click the notch",
                isOn: $expandsOnHover
            )
            SettingsToggleRow(
                title: "Today indicator",
                subtitle: "Progress ring and the number of tasks left in the collapsed notch",
                isOn: $showsIndicator,
                separated: true
            )
            SettingsToggleRow(title: "Sprout", subtitle: "Appears in the notch while a task is in focus", isOn: $showsBuddy, separated: true)
            SettingsRow(minHeight: 44, separated: true) {
                Text("Show on")
                    .settingsTitle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                SettingsPopUp(
                    options: DisplayPreference.allCases.map { ($0, $0.title) },
                    selection: $display
                )
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    var note: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0, content: content)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.04))
                }
            if let note {
                Text(note)
                    .font(.system(size: 11.5))
                    .lineSpacing(2)
                    .padding(.vertical, 1)
                    .foregroundStyle(PanelStyle.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A card row. `separated` draws the hairline above it inside the row's
/// height, as a CSS top border does in the mockups.
struct SettingsRow<Content: View>: View {
    var minHeight: CGFloat = 52
    var separated = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12, content: content)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .padding(.top, separated ? 1 : 0)
            .frame(minHeight: minHeight)
            .overlay(alignment: .top) {
                if separated {
                    Rectangle()
                        .fill(.white.opacity(0.07))
                        .frame(height: 1)
                }
            }
    }
}

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var isOn: Bool
    var minHeight: CGFloat = 52
    var separated = false

    var body: some View {
        SettingsRow(minHeight: minHeight, separated: separated) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .settingsTitle()
                if let subtitle {
                    Text(subtitle)
                        .settingsSubtitle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: $isOn)
                .toggleStyle(PeasySwitchStyle())
        }
    }
}

extension Text {
    func settingsTitle() -> some View {
        font(.system(size: 13))
            .foregroundStyle(PanelStyle.primary)
            .frame(height: 17)
    }

    func settingsSubtitle() -> some View {
        font(.system(size: 11.5))
            .foregroundStyle(PanelStyle.secondary)
            .frame(height: 15)
    }
}

struct LayoutOption: View {
    let layout: PanelLayout
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: PanelLayout

    @State private var isHovered = false

    var body: some View {
        let isSelected = selection == layout
        Button {
            selection = layout
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                LayoutThumbnail(layout: layout)
                    .aspectRatio(200 / 112, contentMode: .fit)
                    .overlay {
                        let width: CGFloat = isSelected ? 2 : 1
                        RoundedRectangle(cornerRadius: 9 + width, style: .continuous)
                            .strokeBorder(
                                isSelected ? PanelStyle.green : .white.opacity(isHovered ? 0.28 : 0.1),
                                lineWidth: width
                            )
                            .padding(-width)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? PanelStyle.primary : PanelStyle.secondary)
                        .frame(height: 17)
                    Text(subtitle)
                        .settingsSubtitle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LayoutThumbnail: View {
    let layout: PanelLayout

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 200
            context.scaleBy(x: scale, y: scale)
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 112), cornerRadius: 9),
                with: .color(Color(hex: "#2C2C2F"))
            )
            context.fill(
                Path(roundedRect: CGRect(x: 24, y: -14, width: 152, height: 110), cornerRadius: 14),
                with: .color(.black)
            )
            switch layout {
            case .vertical: drawVertical(in: context)
            case .horizontal: drawHorizontal(in: context)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawVertical(in context: GraphicsContext) {
        bar(context, x: 31, y: 15, width: 45, height: 10, radius: 3, opacity: 0.16)
        let sidebar: [(CGFloat, String, CGFloat, Double)] = [
            (20, "#30D158", 22, 0.8), (33, "#8E8E93", 24, 0.38), (44, "#0A84FF", 18, 0.38),
            (55, "#FF9F0A", 20, 0.38), (66, "#30D158", 14, 0.38),
        ]
        for (y, color, width, opacity) in sidebar {
            dot(context, x: 37, y: y, color: color)
            bar(context, x: 43, y: y - 1.5, width: width, height: 3, radius: 1.5, opacity: opacity)
        }
        bar(context, x: 83, y: 14, width: 1, height: 70, radius: 0, opacity: 0.12)
        let rows: [(CGFloat, String, CGFloat)] = [
            (20, "#0A84FF", 50), (32, "#0A84FF", 40), (44, "#0A84FF", 46), (56, "#8E8E93", 32), (68, "#30D158", 38),
        ]
        for (y, color, width) in rows {
            ring(context, x: 96, y: y, color: color)
            bar(context, x: 104, y: y - 1.5, width: width, height: 3, radius: 1.5, opacity: 0.6)
        }
    }

    private func drawHorizontal(in context: GraphicsContext) {
        bar(context, x: 31, y: 14, width: 36, height: 11, radius: 5.5, opacity: 0.16)
        let tabs: [(CGFloat, String, CGFloat, Double)] = [
            (38, "#30D158", 18, 0.8), (76, "#8E8E93", 18, 0.38), (108, "#0A84FF", 14, 0.38), (136, "#FF9F0A", 14, 0.38),
        ]
        for (x, color, width, opacity) in tabs {
            dot(context, x: x, y: 19.5, color: color)
            bar(context, x: x + 5, y: 18, width: width, height: 3, radius: 1.5, opacity: opacity)
        }
        let rows: [(CGFloat, String, CGFloat)] = [(38, "#0A84FF", 84), (50, "#0A84FF", 70), (62, "#8E8E93", 78), (74, "#30D158", 58)]
        for (y, color, width) in rows {
            ring(context, x: 38, y: y, color: color)
            bar(context, x: 46, y: y - 1.5, width: width, height: 3, radius: 1.5, opacity: 0.6)
            bar(context, x: 148, y: y - 1.5, width: 20, height: 3, radius: 1.5, opacity: 0.25)
        }
    }

    private func bar(_ context: GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, opacity: Double) {
        context.fill(
            Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius),
            with: .color(.white.opacity(opacity))
        )
    }

    private func dot(_ context: GraphicsContext, x: CGFloat, y: CGFloat, color: String) {
        context.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)), with: .color(Color(hex: color)))
    }

    private func ring(_ context: GraphicsContext, x: CGFloat, y: CGFloat, color: String) {
        context.stroke(
            Path(ellipseIn: CGRect(x: x - 3.2, y: y - 3.2, width: 6.4, height: 6.4)),
            with: .color(Color(hex: color)),
            lineWidth: 1.3
        )
    }
}

struct PeasySwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? PanelStyle.green : Color.white.opacity(0.2))
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                    .padding(2)
            }
            .frame(width: 38, height: 22)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }
}
