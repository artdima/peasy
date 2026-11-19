import SwiftUI

struct TaskSchedulePicker: View {
    static let bodySize = CGSize(width: 300, height: 500)
    static let arrowDepth: CGFloat = 9
    static let windowSize = CGSize(width: bodySize.width + arrowDepth, height: bodySize.height)

    @Bindable var model: PanelViewModel
    let arrowEdge: HorizontalEdge
    let arrowY: CGFloat
    let onClose: () -> Void

    @State private var month: Date
    @State private var remindersOff = false

    init(model: PanelViewModel, arrowEdge: HorizontalEdge, arrowY: CGFloat, onClose: @escaping () -> Void) {
        self.model = model
        self.arrowEdge = arrowEdge
        self.arrowY = arrowY
        self.onClose = onClose
        _month = State(initialValue: ScheduleDates.startOfMonth(model.scheduleDraft.date ?? .now))
    }

    var body: some View {
        let today = DayClock.shared.today
        VStack(spacing: 0) {
            quickChoices(today: today)
            PickerDivider()
            MonthCalendar(month: $month, selection: model.scheduleDraft.date, today: today) { day in
                model.scheduleDraft.date = ScheduleDates.day(day, keepingTimeOf: model.scheduleDraft)
            }
            PickerDivider()
            timeRow
            PickerDivider()
            footer(today: today)
        }
        .frame(width: Self.bodySize.width - 2, height: Self.bodySize.height - 2)
        .padding(1)
        .padding(arrowEdge == .leading ? .leading : .trailing, Self.arrowDepth)
        .background {
            let shape = PickerShape(arrowEdge: arrowEdge, arrowY: arrowY, depth: Self.arrowDepth)
            ZStack {
                shape.fill(PickerStyle.background)
                shape.stroke(PickerStyle.border, lineWidth: 2)
            }
            .clipShape(shape)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .onExitCommand(perform: onClose)
    }

    private func quickChoices(today: Date) -> some View {
        let tomorrow = ScheduleDates.adding(days: 1, to: today)
        let weekend = ScheduleDates.weekend(after: today)
        let nextWeek = ScheduleDates.nextWeek(after: today)
        return VStack(spacing: 2) {
            QuickChoice(title: "Today", detail: ScheduleFormat.weekday(today)) {
                SproutIcon()
                    .frame(width: 15, height: 15)
            } action: {
                choose(today)
            }
            QuickChoice(title: "Tomorrow", detail: ScheduleFormat.weekday(tomorrow)) {
                Glyph(kind: .sun, size: 15)
                    .foregroundStyle(Color(nsColor: .systemOrange))
            } action: {
                choose(tomorrow)
            }
            QuickChoice(title: "This Weekend", detail: ScheduleFormat.weekdayDayMonth(weekend, now: today)) {
                Glyph(kind: .sofa, size: 15)
                    .foregroundStyle(Color(nsColor: .systemBlue))
            } action: {
                choose(weekend)
            }
            QuickChoice(title: "Next Week", detail: ScheduleFormat.weekdayDayMonth(nextWeek, now: today)) {
                Glyph(kind: .nextWeek, size: 14)
                    .foregroundStyle(PanelStyle.secondary)
            } action: {
                choose(nextWeek)
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }

    private var timeRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Time")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelStyle.primary)
                if model.scheduleDraft.hasTime, remindersOff {
                    Text("Notifications are off")
                        .font(.system(size: 11))
                        .foregroundStyle(PanelStyle.secondary)
                }
            }
            Spacer(minLength: 0)
            if model.scheduleDraft.hasTime {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
                    .labelsHidden()
                    .fixedSize()
            }
            Toggle("Time", isOn: hasTimeBinding)
                .toggleStyle(PeasySwitchStyle())
                .labelsHidden()
        }
        .padding(.leading, 16)
        .padding(.trailing, 13)
        .frame(height: 44)
    }

    private func footer(today: Date) -> some View {
        HStack(spacing: 8) {
            ScheduleFormat.summary(of: model.scheduleDraft, now: today)
                .font(.system(size: 13))
                .foregroundStyle(PanelStyle.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if model.scheduleDraft.date != nil {
                FooterButton(title: "Remove Date") {
                    model.scheduleDraft = ScheduleDraft()
                    onClose()
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 17)
        .frame(height: 41)
    }

    private var hasTimeBinding: Binding<Bool> {
        Binding {
            model.scheduleDraft.hasTime
        } set: { isOn in
            var draft = model.scheduleDraft
            draft.hasTime = isOn
            if isOn {
                draft.date = ScheduleDates.suggestedTime(on: draft.date ?? .now)
                Task {
                    remindersOff = !(await Reminders.shared.requestPermission())
                }
            } else if let date = draft.date {
                draft.date = Calendar.current.startOfDay(for: date)
            }
            model.scheduleDraft = draft
        }
    }

    private var timeBinding: Binding<Date> {
        Binding {
            model.scheduleDraft.date ?? .now
        } set: { time in
            model.scheduleDraft.date = ScheduleDates.day(model.scheduleDraft.date ?? .now, at: time)
        }
    }

    private func choose(_ day: Date) {
        model.scheduleDraft.date = ScheduleDates.day(day, keepingTimeOf: model.scheduleDraft)
        onClose()
    }
}

enum PickerStyle {
    static let background = Color.themed(dark: "#232325", light: "#FCFCFD")
    static let border = Color.themed(dark: NSColor(hex: "#39393B"), light: NSColor.black.withAlphaComponent(0.12))
    static let divider = Color.themed(dark: NSColor(hex: "#343436"), light: NSColor.black.withAlphaComponent(0.08))
    static let hover = Color.themed(dark: NSColor(hex: "#3E3E40"), light: NSColor.black.withAlphaComponent(0.06))
    static let pastDay = Color.themed(dark: "#58585A", light: "#B4B4B8")
    static let otherMonthDay = Color.themed(dark: "#3D3D3F", light: "#D6D6DA")
}

private struct PickerDivider: View {
    var body: some View {
        Rectangle()
            .fill(PickerStyle.divider)
            .frame(height: 1)
    }
}

private struct QuickChoice<Icon: View>: View {
    let title: LocalizedStringKey
    let detail: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                icon()
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(PanelStyle.primary)
                Spacer(minLength: 8)
                Text(verbatim: detail)
                    .font(.system(size: 12))
                    .foregroundStyle(PanelStyle.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(isHovered ? PickerStyle.hover : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FooterButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(isHovered ? PanelStyle.primary : PanelStyle.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct MonthCalendar: View {
    @Binding var month: Date
    let selection: Date?
    let today: Date
    let onSelect: (Date) -> Void

    var body: some View {
        let calendar = Calendar.current
        let days = ScheduleDates.grid(for: month)
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Text(verbatim: ScheduleFormat.monthTitle(month))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PanelStyle.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MonthButton(label: "Previous Month") {
                    MonthChevron()
                        .scaleEffect(x: -1)
                } action: {
                    month = ScheduleDates.adding(months: -1, to: month)
                }
                MonthButton(label: "This Month") {
                    Circle()
                        .frame(width: 5.5, height: 5.5)
                } action: {
                    month = ScheduleDates.startOfMonth(today)
                }
                MonthButton(label: "Next Month") {
                    MonthChevron()
                } action: {
                    month = ScheduleDates.adding(months: 1, to: month)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 3)
            .frame(height: 24)
            .padding(.bottom, 2)

            HStack(spacing: 0) {
                ForEach(ScheduleFormat.weekdaySymbols(), id: \.self) { symbol in
                    Text(verbatim: symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PanelStyle.secondary)
                        .frame(width: 40)
                }
            }
            .frame(height: 20)

            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(days[(week * 7)..<(week * 7 + 7)], id: \.self) { day in
                            DayCell(
                                day: day,
                                isSelected: selection.map { calendar.isDate($0, inSameDayAs: day) } == true,
                                isToday: calendar.isDate(day, inSameDayAs: today),
                                isPast: day < calendar.startOfDay(for: today),
                                isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month)
                            ) {
                                onSelect(day)
                                if !calendar.isDate(day, equalTo: month, toGranularity: .month) {
                                    month = ScheduleDates.startOfMonth(day)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 12)
        .padding(.bottom, 7)
    }
}

private struct MonthButton<Icon: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            icon()
                .foregroundStyle(isHovered ? PanelStyle.primary : PanelStyle.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct MonthChevron: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0.7, y: 0.7))
            path.addLine(to: CGPoint(x: 4.3, y: 4))
            path.addLine(to: CGPoint(x: 0.7, y: 7.3))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        .frame(width: 5, height: 8)
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let isPast: Bool
    let isInMonth: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: "\(Calendar.current.component(.day, from: day))")
                .font(.system(size: 13, weight: isSelected || isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(isSelected ? PanelStyle.green : isHovered && !isPast ? PickerStyle.hover : .clear)
                }
                .frame(width: 40, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isPast)
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text(day, format: .dateTime.day().month(.wide).weekday(.wide)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var color: Color {
        if isSelected { return .black }
        if !isInMonth { return PickerStyle.otherMonthDay }
        if isPast { return PickerStyle.pastDay }
        if isToday { return PanelStyle.green }
        return PanelStyle.primary
    }
}

struct PickerShape: Shape {
    let arrowEdge: HorizontalEdge
    let arrowY: CGFloat
    let depth: CGFloat
    var cornerRadius: CGFloat = 14
    var arrowHalfHeight: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = arrowEdge == .leading ? rect.minX + depth : rect.minX
        let right = arrowEdge == .trailing ? rect.maxX - depth : rect.maxX
        let body = CGRect(x: left, y: rect.minY, width: right - left, height: rect.height)
        let r = min(cornerRadius, body.width / 2, body.height / 2)
        let y = min(max(arrowY, body.minY + r + arrowHalfHeight), body.maxY - r - arrowHalfHeight)

        path.move(to: CGPoint(x: body.minX + r, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
        if arrowEdge == .trailing {
            path.addLine(to: CGPoint(x: body.maxX, y: y - arrowHalfHeight))
            path.addLine(to: CGPoint(x: rect.maxX - 1.2, y: y - 1.1))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 1.2, y: y + 1.1), control: CGPoint(x: rect.maxX, y: y))
            path.addLine(to: CGPoint(x: body.maxX, y: y + arrowHalfHeight))
        }
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
        path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
        if arrowEdge == .leading {
            path.addLine(to: CGPoint(x: body.minX, y: y + arrowHalfHeight))
            path.addLine(to: CGPoint(x: rect.minX + 1.2, y: y + 1.1))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 1.2, y: y - 1.1), control: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: body.minX, y: y - arrowHalfHeight))
        }
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        path.closeSubpath()
        return path
    }
}
