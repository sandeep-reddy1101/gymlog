import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @State private var exerciseID: UUID?
    @State private var metric: StrengthMetric = .estimatedMax
    private var recordedExercises: [ExerciseRecord] {
        let ids = Set(store.finished.flatMap(\.logs).filter { $0.sets.contains(where: \.completed) }.map(\.id))
        return store.exercises.filter { ids.contains($0.id) }
    }
    private var chosen: ExerciseRecord? {
        store.exercises.first { $0.id == exerciseID } ?? recordedExercises.first ?? store.exercises.first
    }
    private var performances: [ExercisePerformance] {
        guard let chosen else { return [] }
        return WorkoutLogic.performances(for: chosen.id, in: store.finished)
    }
    private var resolvedMetric: StrengthMetric { chosen?.isBodyweight == true && metric == .estimatedMax ? .reps : metric }
    private var metricUnit: String { resolvedMetric == .reps ? "reps" : store.unit.rawValue }
    private var trend: [HealthPoint] {
        performances.map { performance in
            let value: Double
            switch resolvedMetric {
            case .estimatedMax: value = store.unit.display(performance.score)
            case .weight: value = store.unit.display(performance.maxWeight)
            case .reps: value = Double(performance.bestReps)
            }
            return HealthPoint(id: performance.id, date: performance.date, value: value)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    stats
                    consistency
                    heatmap
                    Panel {
                        Text("Weekly volume").font(.title3.bold())
                        Text("Last 8 weeks · \(store.unit.rawValue) × reps").font(.caption).foregroundStyle(theme.secondary)
                        Chart(WorkoutLogic.weeklyVolumes(store.finished)) { point in
                            BarMark(x: .value("Week", point.date, unit: .weekOfYear), y: .value("Volume", store.unit.display(point.value)))
                                .foregroundStyle(DayType.pull.color.gradient).cornerRadius(5)
                        }.frame(height: 180).chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day(), anchor: .center) } }
                        if store.finished.isEmpty { Text("Finish a workout to start your chart.").font(.caption).foregroundStyle(theme.secondary) }
                    }
                    strengthPanel
                    records
                    Panel {
                        Text("Recovery trends").font(.title3.bold())
                        HealthConnectionStatus()
                        HealthTrend(title: "Resting heart rate", unit: "bpm", points: store.health.restingHeartRate, color: .pink)
                        HealthTrend(title: "Heart rate variability", unit: "ms · SDNN", points: store.health.variability, color: .teal)
                        if store.health.restingHeartRate.isEmpty && store.health.variability.isEmpty {
                            Text("No readable data. Connect Apple Health in Settings; permission may be off or your Watch may not have synced.")
                                .font(.subheadline).foregroundStyle(theme.secondary)
                        }
                    }
                }.padding()
            }.background(theme.canvas).studioScreen().navigationTitle("Progress")
                .task {
                    if !store.isDemo && store.health.hasRequestedAccess {
                        do { try await store.health.loadTrends() }
                        catch { store.health.status = "Health trends unavailable: \(error.localizedDescription)" }
                    }
                }
        }
    }
    private var consistency: some View {
        let goal = store.data.preferences.resolvedWeeklyGoal
        let counts = WorkoutLogic.weeklyCounts(store.finished)
        let current = Int(counts.last?.value ?? 0)
        let streak = WorkoutLogic.goalStreak(store.finished, goal: goal)
        return Panel {
            Label("Weekly consistency", systemImage: "calendar.badge.checkmark").font(.title3.bold())
            Text("\(current) of \(goal) workouts this week").font(.title2.bold()).monospacedDigit()
            SwiftUI.ProgressView(value: Double(min(current, goal)), total: Double(goal)).tint(.teal)
            Text(current >= goal ? "You’ve reached your weekly goal." : "\(goal - current) more to reach your goal.")
                .font(.subheadline).foregroundStyle(theme.secondary)
            Text("\(streak) consecutive goal \(streak == 1 ? "week" : "weeks") · Monday–Sunday")
                .font(.caption).foregroundStyle(theme.secondary)
            Chart {
                ForEach(counts) { point in
                    BarMark(x: .value("Week", point.date, unit: .weekOfYear), y: .value("Workouts", point.value))
                        .foregroundStyle(.teal.gradient).cornerRadius(4)
                }
                RuleMark(y: .value("Goal", goal)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(theme.secondary)
            }.frame(height: 130)
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day(), anchor: .center) } }
                .chartYAxis { AxisMarks(values: .stride(by: 1)) }
            Text("Dashed line: your current goal. Change it in Settings. An unfinished current week does not break your streak.").font(.caption).foregroundStyle(theme.secondary)
        }
    }
    private var strengthPanel: some View {
        Panel {
            Text("Your strength, over time").font(.title3.bold())
            Picker("Exercise", selection: Binding(get: { chosen?.id }, set: { exerciseID = $0 })) {
                if !recordedExercises.isEmpty {
                    Section("With workout history") { ForEach(recordedExercises) { Text($0.name).tag(Optional($0.id)) } }
                }
                Section("All exercises") { ForEach(store.exercises.filter { exercise in !recordedExercises.contains { $0.id == exercise.id } }) { Text($0.name).tag(Optional($0.id)) } }
            }.pickerStyle(.menu)
            Picker("Metric", selection: Binding(get: { resolvedMetric }, set: { metric = $0 })) {
                ForEach(StrengthMetric.allCases.filter { chosen?.isBodyweight != true || $0 != .estimatedMax }) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
            Text(resolvedMetric == .estimatedMax ? "Estimated 1-rep max · Epley · \(store.unit.rawValue)" : resolvedMetric == .weight ? "Heaviest completed set · \(store.unit.rawValue) of added load" : "Most reps in a completed set · Weight may differ between sessions")
                .font(.caption).foregroundStyle(theme.secondary)
            if trend.isEmpty {
                ContentUnavailableView("No sets yet", systemImage: "chart.xyaxis.line", description: Text("Complete a set of this exercise to see your trend."))
            } else {
                Chart(trend) { point in
                    LineMark(x: .value("Date", point.date), y: .value(metricUnit, point.value)).foregroundStyle(.purple)
                    PointMark(x: .value("Date", point.date), y: .value(metricUnit, point.value)).foregroundStyle(.purple)
                }.frame(height: 180)
                if let latest = trend.last {
                    Text("Latest: \(latest.value, format: .number.precision(.fractionLength(0...1))) \(metricUnit)").font(.headline)
                    if trend.count >= 2 {
                        let delta = latest.value - trend[trend.count - 2].value
                        Text("\(delta > 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(0...1)))) \(metricUnit) vs previous session")
                            .font(.subheadline).foregroundStyle(delta > 0 ? Color.teal : Color.secondary)
                    }
                }
                Divider().padding(.vertical, 6)
                Text("Recent sets").font(.headline)
                ForEach(Array(performances.suffix(3).reversed())) { performance in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(performance.date, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(theme.secondary)
                        Text(performance.sets.map { "\(store.unit.text($0.weightKg)) × \($0.reps)" }.joined(separator: "  ·  ") + " \(store.unit.rawValue)")
                            .font(.subheadline.monospacedDigit())
                    }.padding(.vertical, 4)
                }
            }
        }
    }
    private var stats: some View {
        let week = WorkoutLogic.calendar.dateInterval(of: .weekOfYear, for: .now)!
        return Panel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { statValues(week) }
                VStack(alignment: .leading, spacing: 16) { statValues(week) }
            }
        }
    }
    @ViewBuilder private func statValues(_ week: DateInterval) -> some View {
        stat("Workouts", value: String(store.finished.count))
        stat("This week", value: String(store.finished.filter { $0.start >= week.start && $0.start < week.end }.count))
        stat("Volume (\(store.unit.rawValue))", value: store.unit.display(store.finished.reduce(0) { $0 + $1.volume }).formatted(.number.notation(.compactName).precision(.fractionLength(0...1))))
    }
    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(theme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var heatmap: some View {
        let cal = WorkoutLogic.calendar
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)!.start
        let start = cal.date(byAdding: .day, value: -21, to: weekStart)!
        return Panel {
            Text("Show up. Build momentum.").font(.title3.bold())
            Text("4 weeks · Monday–Sunday").font(.caption).foregroundStyle(theme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(0..<7) { offset in Text(["M","T","W","T","F","S","S"][offset]).font(.caption2).foregroundStyle(theme.secondary) }
                ForEach(0..<28) { index in
                    let date = cal.date(byAdding: .day, value: index, to: start)!
                    let workouts = store.finished.filter { cal.isDate($0.start, inSameDayAs: date) }
                    VStack(spacing: 3) {
                        Text("\(cal.component(.day, from: date))").font(.caption.bold())
                        HStack(spacing: 2) {
                            ForEach(Array(Set(workouts.map(\.dayType))).sorted { $0.weekday < $1.weekday }) { type in
                                Circle().fill(type.color).frame(width: 4, height: 4)
                            }
                        }.frame(height: 4)
                    }.frame(maxWidth: .infinity, minHeight: 38)
                        .background(workouts.first?.dayType.color.opacity(0.25) ?? Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cal.isDateInToday(date) ? Color.primary : .clear, lineWidth: 1))
                        .opacity(date > .now ? 0.35 : 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(workouts.isEmpty ? "No workout" : workouts.map { $0.title }.joined(separator: ", "))")
                }
            }.padding(.top, 10)
            ViewThatFits {
                HStack { legend }
                VStack(alignment: .leading) { legend }
            }.padding(.top, 8)
        }
    }
    @ViewBuilder private var legend: some View {
        ForEach(DayType.allCases) { day in
            Label { Text(day.colorName).font(.caption2) } icon: { Circle().fill(day.color).frame(width: 6, height: 6) }
        }
    }
    private var records: some View {
        let recent = store.finished.prefix(10).flatMap { session in
            WorkoutLogic.records(in: session, history: store.finished).map { log in
                (id: session.id.uuidString + log.id.uuidString, log: log, date: session.start)
            }
        }
        return Panel {
            Label("Personal records", systemImage: "trophy.fill").font(.title3.bold()).foregroundStyle(.orange)
            if recent.isEmpty {
                Text("Your first session sets the baseline. Beat it to earn a badge.").font(.subheadline).foregroundStyle(theme.secondary)
            }
            ForEach(Array(recent.prefix(5)), id: \.id) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "medal.fill").foregroundStyle(.orange).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.log.exercise.name).font(.subheadline.bold())
                        Text(entry.log.exercise.isBodyweight ? "\(Int(entry.log.score)) reps · Best completed reps" : "\(store.unit.text(entry.log.score)) \(store.unit.rawValue) · Estimated 1RM")
                            .font(.caption).foregroundStyle(theme.secondary)
                        Text(entry.date, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(theme.secondary)
                    }
                }.padding(.top, 8)
            }
        }
    }
}

struct HealthTrend: View {
    @Environment(\.appTheme) private var theme
    var title: String
    var unit: String
    var points: [HealthPoint]
    var color: Color
    var body: some View {
        if !points.isEmpty {
            Text("\(title) · \(unit)").font(.subheadline.bold()).padding(.top, 12)
            Chart(points) { point in
                LineMark(x: .value("Date", point.date), y: .value(unit, point.value)).foregroundStyle(color)
                PointMark(x: .value("Date", point.date), y: .value(unit, point.value)).foregroundStyle(color)
            }.frame(height: 130)
        }
    }
}

private enum StrengthMetric: String, CaseIterable, Identifiable {
    case estimatedMax = "Strength estimate", weight = "Heaviest weight", reps = "Best reps"
    var id: String { rawValue }
}
