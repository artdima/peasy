import SwiftData
import SwiftUI

struct NewTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]

    @State private var title = ""
    @State private var noteOrLink = ""
    @State private var projectID: UUID?
    @State private var schedule: ScheduleDraft
    @State private var isForClaude = false
    @State private var showsSchedule = false
    @FocusState private var isTitleFocused: Bool

    init(projectID: UUID?) {
        _projectID = State(initialValue: projectID)
        _schedule = State(initialValue: ScheduleDraft(date: DayClock.shared.today))
    }

    var body: some View {
        let today = DayClock.shared.today
        let color = Color(hex: selectedProject?.colorHex ?? ProjectPalette.noProject)
        let isReady = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Text("New task")
                        .font(.headline)
                        .foregroundStyle(PanelStyle.title)
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PanelStyle.secondary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        Spacer()
                    }
                }
                .padding(.top, 8)

                HStack(spacing: 12) {
                    DraftRing(color: color, isForClaude: assignsToClaude)
                    TextField("What needs to be done?", text: $title)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(PanelStyle.title)
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit(submit)
                        .accessibilityLabel(Text("Task title"))
                    Button(action: submit) {
                        Glyph(kind: .returnKey, size: 16)
                            .foregroundStyle(isReady ? Color.black : PanelStyle.tertiary)
                            .frame(width: 34, height: 34)
                            .background(isReady ? color : PhoneStyle.pill, in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isReady)
                    .accessibilityLabel(Text("Add task"))
                }
                .padding(.leading, 20)
                .padding(.trailing, 12)
                .padding(.top, 10)

                TextField("Note or link", text: $noteOrLink, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .padding(.leading, 56)
                    .padding(.trailing, 20)

                Rectangle()
                    .fill(PanelStyle.separator)
                    .frame(height: 1)
                    .padding(.leading, 20)
                    .padding(.top, 16)

                section("Project") {
                    PhonePill(title: Text("No Project"), isSelected: projectID == nil, action: { projectID = nil }) {
                        ColorDot(hex: ProjectPalette.noProject)
                    }
                    ForEach(projects) { project in
                        PhonePill(title: Text(project.name), isSelected: projectID == project.id, action: { projectID = project.id }) {
                            ColorDot(hex: project.colorHex)
                        }
                    }
                }

                section("When") {
                    let tomorrow = ScheduleDates.adding(days: 1, to: today)
                    let weekend = ScheduleDates.weekend(after: today)
                    let customDate = customDateLabel(today: today, quickDays: [today, tomorrow, weekend])
                    PhonePill(title: Text("Today"), isSelected: isPicked(today), action: { pick(today) }) {
                        SproutIcon()
                            .frame(width: 16, height: 16)
                    }
                    PhonePill(title: Text("Tomorrow"), isSelected: isPicked(tomorrow), action: { pick(tomorrow) }) {
                        Glyph(kind: .sun, size: 16)
                            .foregroundStyle(Color(hex: "#FF9F0A"))
                    }
                    PhonePill(title: Text("This Weekend"), isSelected: isPicked(weekend), action: { pick(weekend) }) {
                        Glyph(kind: .sofa, size: 16)
                            .foregroundStyle(Color(hex: "#64D2FF"))
                    }
                    PhonePill(title: customDate ?? Text("Date…"), isSelected: customDate != nil, action: { showsSchedule = true }) {
                        Glyph(kind: .calendar, size: 16)
                            .foregroundStyle(Color(hex: "#BF5AF2"))
                    }
                }

                ClaudeToggle(isOn: claudeBinding)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
            }
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(PanelStyle.primary)
        .onAppear {
            isTitleFocused = true
        }
        .sheet(isPresented: $showsSchedule) {
            ScheduleSheet(title: title, draft: $schedule)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(PhoneStyle.sheet)
        }
    }

    private var selectedProject: Project? {
        projects.first { $0.id == projectID }
    }

    private var assignsToClaude: Bool {
        isForClaude || ClaudeMention.parse(title).isForClaude
    }

    private var claudeBinding: Binding<Bool> {
        Binding {
            assignsToClaude
        } set: { newValue in
            isForClaude = newValue
            if !newValue {
                title = ClaudeMention.parse(title).title
            }
        }
    }

    private func section<Pills: View>(_ title: LocalizedStringKey, @ViewBuilder pills: () -> Pills) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PanelStyle.secondary)
                .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    pills()
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 14)
    }

    private func isPicked(_ day: Date) -> Bool {
        guard let date = schedule.date, !schedule.hasTime else { return false }
        return Calendar.current.isDate(date, inSameDayAs: day)
    }

    private func customDateLabel(today: Date, quickDays: [Date]) -> Text? {
        guard let date = schedule.date else { return nil }
        if !schedule.hasTime, quickDays.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
            return nil
        }
        return TaskScheduleLabel.text(date: date, hasTime: schedule.hasTime, isDone: false, inToday: false, now: today)
    }

    private func pick(_ day: Date) {
        schedule = isPicked(day) ? ScheduleDraft() : ScheduleDraft(date: day)
    }

    private func submit() {
        let typed = ClaudeMention.parse(title)
        let attachment = Self.split(noteOrLink)
        let store = TaskStore(context: modelContext)
        guard let task = store.addTask(
            typed.title,
            project: selectedProject,
            date: schedule.date,
            hasTime: schedule.hasTime,
            note: attachment.note,
            link: attachment.link,
            origin: ""
        ) else { return }
        if typed.isForClaude || isForClaude {
            store.assignToClaude(task)
        }
        dismiss()
    }

    static func split(_ text: String) -> (note: String, link: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let scheme = URL(string: trimmed)?.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return (trimmed, "") }
        return ("", trimmed)
    }
}

private struct DraftRing: View {
    let color: Color
    let isForClaude: Bool

    var body: some View {
        ZStack {
            if isForClaude {
                Circle()
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [3, 2.4]))
                Glyph(kind: .sparkle, size: 10, filled: true)
                    .foregroundStyle(PanelStyle.claude)
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

private struct ClaudeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Glyph(kind: .sparkle, size: 16, filled: true)
                    .foregroundStyle(PanelStyle.claude)
                Text("Hand to Claude")
                    .font(.callout)
                    .foregroundStyle(PanelStyle.primary)
                Spacer(minLength: 8)
                Text("or type @claude")
                    .font(.footnote)
                    .foregroundStyle(PanelStyle.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(PanelStyle.claude.opacity(isOn ? 0.22 : 0.08), in: shape)
            .overlay {
                shape.strokeBorder(PanelStyle.claude.opacity(isOn ? 0.9 : 0.35))
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
