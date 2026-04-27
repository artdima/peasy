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

    var body: some View {
        let colorHex = projects.first { $0.id == state.projectID }?.colorHex ?? ProjectPalette.inbox
        let color = Color(hex: colorHex)
        let isReady = !state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                TextField("What needs to be done?", text: $state.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                Button(action: onSubmit) {
                    Image(systemName: "return")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isReady ? Color.black : Color(hex: "#636366"))
                        .frame(width: 30, height: 30)
                        .background(isReady ? color : Color.white.opacity(0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isReady)
                .accessibilityLabel("Add task")
            }
            .frame(height: 44)

            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, -14)

            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    QuickAddChip(title: Text("Inbox"), colorHex: ProjectPalette.inbox, isOn: state.projectID == nil) {
                        state.projectID = nil
                    }
                    ForEach(projects) { project in
                        QuickAddChip(
                            title: Text(verbatim: project.name),
                            colorHex: project.colorHex,
                            isOn: state.projectID == project.id
                        ) {
                            state.projectID = project.id
                        }
                    }
                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 6)
                    TodayChip(isOn: $state.isToday)
                }
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 30)
        }
        .padding(14)
        .frame(width: 560)
        .background(Color(hex: "#151517"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.09))
        }
        .shadow(color: Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255).opacity(0.55), radius: 45, y: 40)
        .shadow(color: Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255).opacity(0.35), radius: 15, y: 10)
        .padding(Self.shadowRoom)
        .foregroundStyle(PanelStyle.primary)
        .environment(\.colorScheme, .dark)
        .onExitCommand(perform: onCancel)
        .onAppear {
            isFocused = true
        }
        .onChange(of: state.focusRequest) {
            isFocused = true
        }
    }
}

struct QuickAddChip: View {
    let title: Text
    let colorHex: String
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ColorDot(hex: colorHex, size: 6)
                title
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .medium))
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
                Text("Today")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isOn ? PanelStyle.green : (isHovered ? PanelStyle.primary : PanelStyle.secondary))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(PanelStyle.green.opacity(isOn ? 0.18 : 0), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(isOn ? 0 : 0.16))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
