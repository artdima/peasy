import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class QuickAddState {
    var title = ""
    var projectID: UUID?
    var isToday = true
    private(set) var focusRequest = 0

    func reset(projectID: UUID?) {
        title = ""
        self.projectID = projectID
        isToday = true
        focusRequest += 1
    }
}

struct QuickAddView: View {
    static let shadowRoom = EdgeInsets(top: 40, leading: 60, bottom: 100, trailing: 60)

    @Bindable var state: QuickAddState
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    private static let card = Color.themed(dark: "#1C1C1E", light: "#F7F7F9")
    private static let stroke = Color.themed(white: 0.09, black: 0.08)
    private static let divider = Color.themed(white: 0.07, black: 0.07)
    private static let groupSeparator = Color.themed(white: 0.14, black: 0.12)
    private static let idleSend = Color.themed(white: 0.08, black: 0.06)
    private static let idleSendGlyph = Color.themed(dark: "#636366", light: "#AEAEB2")
    private static let shadow = Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255)

    var body: some View {
        let colorHex = projects.first { $0.id == state.projectID }?.colorHex ?? ProjectPalette.noProject
        let color = Color(hex: colorHex)
        let isReady = !state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                TextField(text: $state.title, prompt: Text(verbatim: "")) {
                    Text("Task title")
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .overlay(alignment: .leading) {
                        if state.title.isEmpty {
                            Text("What needs to be done?")
                                .font(.system(size: 20))
                                .tracking(-0.2)
                                .foregroundStyle(PanelStyle.tertiary)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .offset(y: 1)
                Button(action: onSubmit) {
                    Glyph(kind: .returnKey, size: 14)
                        .foregroundStyle(isReady ? Color.black : Self.idleSendGlyph)
                        .frame(width: 30, height: 30)
                        .background(isReady ? color : Self.idleSend, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isReady)
                .accessibilityLabel("Add task")
            }
            .frame(height: 44)

            Rectangle()
                .fill(Self.divider)
                .frame(height: 1)
                .padding(.horizontal, -14)

            FlowLayout(spacing: 4, rowSpacing: 4) {
                QuickAddChip(title: String(localized: "No Project"), colorHex: ProjectPalette.noProject, isOn: state.projectID == nil) {
                    state.projectID = nil
                }
                ForEach(projects) { project in
                    QuickAddChip(
                        title: project.name,
                        colorHex: project.colorHex,
                        isOn: state.projectID == project.id
                    ) {
                        state.projectID = project.id
                    }
                }
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Self.groupSeparator)
                        .frame(width: 1, height: 16)
                        .padding(.leading, 6)
                    TodayChip(isOn: $state.isToday)
                }
            }
            .padding(.leading, 30)
        }
        .padding(14)
        .frame(width: 560)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Self.card)
                    .shadow(color: Self.shadow.opacity(0.55), radius: 45, y: 40)
                    .shadow(color: Self.shadow.opacity(0.35), radius: 15, y: 10)
                if colorScheme == .light {
                    GlassBackground(topRadius: 18, bottomRadius: 18)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Self.stroke)
        }
        .padding(Self.shadowRoom)
        .foregroundStyle(PanelStyle.primary)
        .onExitCommand(perform: onCancel)
        .onAppear {
            isFocused = true
        }
        .onChange(of: state.focusRequest) {
            isFocused = true
        }
        .id(theme)
    }
}

struct QuickAddChip: View {
    let title: String
    let colorHex: String
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ColorDot(hex: colorHex, size: 6)
                FittedText(string: title, size: 12, weight: .medium)
            }
            .foregroundStyle(isOn || isHovered ? PanelStyle.primary : PanelStyle.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(hex: colorHex).opacity(isOn ? 0.24 : 0), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct TodayChip: View {
    @Binding var isOn: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                SproutIcon(color: isOn ? PanelStyle.green : (isHovered ? PanelStyle.primary : PanelStyle.secondary))
                    .frame(width: 12, height: 12)
                FittedText(string: String(localized: "Today"), size: 12, weight: .medium)
            }
            .foregroundStyle(isOn ? PanelStyle.green : (isHovered ? PanelStyle.primary : PanelStyle.secondary))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(PanelStyle.green.opacity(isOn ? 0.18 : 0), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isOn ? .clear : Color.themed(white: 0.16, black: 0.14))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
