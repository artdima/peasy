import SwiftUI

struct ScheduleSheet: View {
    let title: String
    @Binding var draft: ScheduleDraft

    @Environment(\.dismiss) private var dismiss
    @State private var month: Date
    @State private var remindersOff = false

    init(title: String, draft: Binding<ScheduleDraft>) {
        self.title = title
        _draft = draft
        _month = State(initialValue: ScheduleDates.startOfMonth(draft.wrappedValue.date ?? .now))
    }

    var body: some View {
        let today = DayClock.shared.today
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                quickChoices(today: today)
                monthHeader
                weekdayRow
                calendar(today: today)
                timeRow
                if draft.date != nil {
                    Button {
                        draft = ScheduleDraft()
                        dismiss()
                    } label: {
                        Text("Remove Date")
                            .font(.callout)
                            .foregroundStyle(PanelStyle.overdue)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(PanelStyle.primary)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Date and Time")
                    .font(.headline)
                    .foregroundStyle(PanelStyle.title)
                if !title.isEmpty {
                    Text(title)
                        .font(.footnote)
                        .foregroundStyle(PanelStyle.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.headline)
            .foregroundStyle(PhoneStyle.accent)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
        }
        .padding(.leading, 20)
        .padding(.top, 12)
    }

    private func quickChoices(today: Date) -> some View {
        let tomorrow = ScheduleDates.adding(days: 1, to: today)
        let weekend = ScheduleDates.weekend(after: today)
        let nextWeek = ScheduleDates.nextWeek(after: today)
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            QuickTile(title: Text("Today"), detail: ScheduleFormat.weekday(today), isSelected: isPicked(today), action: { choose(today) }) {
                SproutIcon()
                    .frame(width: 18, height: 18)
            }
            QuickTile(title: Text("Tomorrow"), detail: ScheduleFormat.weekday(tomorrow), isSelected: isPicked(tomorrow), action: { choose(tomorrow) }) {
                Glyph(kind: .sun, size: 18)
                    .foregroundStyle(Color(hex: "#FFB340"))
            }
            QuickTile(title: Text("This Weekend"), detail: ScheduleFormat.weekday(weekend), isSelected: isPicked(weekend), action: { choose(weekend) }) {
                Glyph(kind: .sofa, size: 18)
                    .foregroundStyle(Color(hex: "#64D2FF"))
            }
            QuickTile(title: Text("Next week"), detail: ScheduleFormat.weekday(nextWeek), isSelected: isPicked(nextWeek), action: { choose(nextWeek) }) {
                Glyph(kind: .nextWeek, size: 18)
                    .foregroundStyle(Color(hex: "#BF5AF2"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Text(verbatim: ScheduleFormat.monthTitle(month))
                .font(.headline)
                .foregroundStyle(PanelStyle.title)
            Spacer(minLength: 8)
            monthButton(-1, label: "Previous Month")
            monthButton(1, label: "Next Month")
        }
        .frame(minHeight: 44)
        .padding(.leading, 20)
        .padding(.trailing, 6)
        .padding(.top, 14)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(ScheduleFormat.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PanelStyle.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private func calendar(today: Date) -> some View {
        let calendar = Calendar.current
        let days = ScheduleDates.grid(for: month)
        let weeks = stride(from: 0, to: days.count, by: 7)
            .map { Array(days[$0..<min($0 + 7, days.count)]) }
            .filter { week in week.contains { calendar.isDate($0, equalTo: month, toGranularity: .month) } }
        return VStack(spacing: 0) {
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayCell(day, today: today, inMonth: calendar.isDate(day, equalTo: month, toGranularity: .month))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func dayCell(_ day: Date, today: Date, inMonth: Bool) -> some View {
        if inMonth {
            let isSelected = draft.date.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
            let isToday = Calendar.current.isDate(day, inSameDayAs: today)
            let color: Color = isSelected ? PanelStyle.selectedPrimary : (isToday ? PanelStyle.green : (day < today ? PhoneStyle.pastDay : PanelStyle.primary))
            Button {
                draft.date = ScheduleDates.day(day, keepingTimeOf: draft)
            } label: {
                Text(day, format: .dateTime.day())
                    .font(.title3.weight(isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? PanelStyle.pillSelection : Color.clear, in: Circle())
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(day, format: .dateTime.day().month(.wide).weekday(.wide)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 42)
        }
    }

    private var timeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundStyle(PanelStyle.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Time")
                    .font(.callout)
                if draft.hasTime, remindersOff {
                    Text("Notifications are off")
                        .font(.caption)
                        .foregroundStyle(PanelStyle.secondary)
                }
            }
            Spacer(minLength: 8)
            if draft.hasTime {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Toggle("Time", isOn: hasTimeBinding)
                .labelsHidden()
                .tint(PanelStyle.green)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(minHeight: 52)
        .background(PhoneStyle.pill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func monthButton(_ step: Int, label: LocalizedStringKey) -> some View {
        Button {
            withAnimation(.snappy) {
                month = ScheduleDates.adding(months: step, to: month)
            }
        } label: {
            Glyph(kind: .chevron, size: 14)
                .rotationEffect(.degrees(step < 0 ? 180 : 0))
                .foregroundStyle(PhoneStyle.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var hasTimeBinding: Binding<Bool> {
        Binding {
            draft.hasTime
        } set: { isOn in
            var updated = draft
            updated.hasTime = isOn
            if isOn {
                updated.date = ScheduleDates.suggestedTime(on: updated.date ?? .now)
                Task {
                    remindersOff = !(await Reminders.shared.requestPermission())
                }
            } else if let date = updated.date {
                updated.date = Calendar.current.startOfDay(for: date)
            }
            draft = updated
        }
    }

    private var timeBinding: Binding<Date> {
        Binding {
            draft.date ?? .now
        } set: { time in
            draft.date = ScheduleDates.day(draft.date ?? .now, at: time)
        }
    }

    private func isPicked(_ day: Date) -> Bool {
        guard let date = draft.date else { return false }
        return Calendar.current.isDate(date, inSameDayAs: day)
    }

    private func choose(_ day: Date) {
        draft.date = ScheduleDates.day(day, keepingTimeOf: draft)
        dismiss()
    }
}

private struct QuickTile<Icon: View>: View {
    let title: Text
    let detail: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                title
                    .font(.callout.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? PanelStyle.selectedPrimary : PanelStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(verbatim: detail)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? PanelStyle.selectedTertiary : PanelStyle.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isSelected ? PanelStyle.pillSelection : PhoneStyle.pill, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
