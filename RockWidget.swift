// RockWidget.swift — интерактивный виджет «Камень» для iOS 17+
// Положи этот файл в таргет Widget Extension вместо сгенерированного Xcode.
// Тап по виджету → камень меняет настроение. Не трогаешь 20 минут → засыпает.

import WidgetKit
import SwiftUI
import AppIntents
import ClockHandKit          // https://github.com/giljihun/ClockHandKit (работает на iOS 26.1+)

// MARK: - «Мотор» постоянной анимации
// В виджетах обычная анимация не работает, но есть скрытый эффект часовой стрелки:
// вью крутится сама, бесконечно и плавно. Из нескольких таких вращений
// складывается любое «живое» движение (как эпициклы у планет).

extension View {
    /// Бесконечное вращение: один оборот за `period` секунд. reverse = против часовой.
    @ViewBuilder
    func spinning(_ period: TimeInterval, reverse: Bool = false) -> some View {
        if reverse {
            // зеркало → вращение → зеркало = вращение в обратную сторону
            self.scaleEffect(x: -1, y: 1)
                .clockHandRotationEffect(period: .custom(period))
                .scaleEffect(x: -1, y: 1)
        } else {
            self.clockHandRotationEffect(period: .custom(period))
        }
    }

    /// Камень сам гуляет по виджету по петляющей траектории и не переворачивается.
    /// Траектория = круг радиусом r1 (оборот за 12 с) + круг r2 в обратную сторону (5 с).
    func wandering(r1: CGFloat = 14, r2: CGFloat = 6) -> some View {
        self
            .spinning(5)                        // компенсирует поворот → камень всегда «стоит»
            .offset(x: r2)
            .spinning(60.0 / 17.0, reverse: true) // 1/12 + 1/5 = 17/60 оборота в секунду
            .offset(x: r1)
            .spinning(12)
    }
}

// MARK: - Настроения

enum Mood: Int, CaseIterable {
    case happy, surprised, angry, love, sleepy

    var phrase: String {
        switch self {
        case .happy:     return "хе-хе"
        case .surprised: return "чё?!"
        case .angry:     return "не тыкай"
        case .love:      return "люблю тебя"
        case .sleepy:    return "zzz…"
        }
    }
}

// MARK: - Хранилище состояния

enum Store {
    // Интент кнопки выполняется в процессе самого виджета, поэтому хватает .standard.
    // Если захочешь показывать камень и в основном приложении — заведи App Group
    // и используй UserDefaults(suiteName: "group.твой.id")!
    static let d = UserDefaults.standard

    static var mood: Mood {
        get { Mood(rawValue: d.integer(forKey: "mood")) ?? .happy }
        set { d.set(newValue.rawValue, forKey: "mood") }
    }
    static var pokes: Int {
        get { d.integer(forKey: "pokes") }
        set { d.set(newValue, forKey: "pokes") }
    }
    static var lastPoke: Date {
        get { d.object(forKey: "lastPoke") as? Date ?? .distantPast }
        set { d.set(newValue, forKey: "lastPoke") }
    }
}

// MARK: - Действие по тапу (это и делает виджет интерактивным)

struct PokeRockIntent: AppIntent {
    static var title: LocalizedStringResource = "Тыкнуть камень"

    func perform() async throws -> some IntentResult {
        let options = Mood.allCases.filter { $0 != .sleepy && $0 != Store.mood }
        Store.mood = options.randomElement() ?? .happy
        Store.pokes += 1
        Store.lastPoke = .now
        return .result()   // после этого WidgetKit сам перерисует виджет
    }
}

// MARK: - Таймлайн

struct RockEntry: TimelineEntry {
    let date: Date
    let mood: Mood
    let pokes: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RockEntry {
        RockEntry(date: .now, mood: .happy, pokes: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (RockEntry) -> Void) {
        completion(RockEntry(date: .now, mood: Store.mood, pokes: Store.pokes))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RockEntry>) -> Void) {
        let now = Date()
        let sleepAt = Store.lastPoke.addingTimeInterval(20 * 60)
        var entries = [RockEntry(date: now,
                                 mood: now >= sleepAt ? .sleepy : Store.mood,
                                 pokes: Store.pokes)]
        if sleepAt > now {
            entries.append(RockEntry(date: sleepAt, mood: .sleepy, pokes: Store.pokes))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

// MARK: - Рисуем камень

struct RockShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.10, y: h * 0.60))
        p.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.02),
                   control1: CGPoint(x: w * 0.00, y: h * 0.20),
                   control2: CGPoint(x: w * 0.30, y: h * 0.00))
        p.addCurve(to: CGPoint(x: w * 0.97, y: h * 0.62),
                   control1: CGPoint(x: w * 0.85, y: h * 0.05),
                   control2: CGPoint(x: w * 1.02, y: h * 0.35))
        p.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.98),
                   control1: CGPoint(x: w * 0.92, y: h * 0.92),
                   control2: CGPoint(x: w * 0.70, y: h * 1.00))
        p.addCurve(to: CGPoint(x: w * 0.10, y: h * 0.60),
                   control1: CGPoint(x: w * 0.20, y: h * 0.96),
                   control2: CGPoint(x: w * 0.05, y: h * 0.85))
        p.closeSubpath()
        return p
    }
}

struct Mouth: Shape {
    let mood: Mood
    func path(in r: CGRect) -> Path {
        var p = Path()
        switch mood {
        case .happy, .love:
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                           control: CGPoint(x: r.midX, y: r.minY + r.height * 1.6))
        case .angry:
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                           control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
        case .surprised:
            p.addEllipse(in: CGRect(x: r.midX - 5, y: r.minY - 2, width: 10, height: r.height + 4))
        case .sleepy:
            p.move(to: CGPoint(x: r.minX + 4, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX - 4, y: r.midY))
        }
        return p
    }
}

struct Eye: View {
    let mood: Mood
    var body: some View {
        switch mood {
        case .sleepy:
            Capsule().fill(.black).frame(width: 12, height: 3)
        case .love:
            Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(.red)
        default:
            ZStack {
                Circle().fill(.white).frame(width: 14, height: 14)
                // зрачок сам «оглядывается» по кругу
                Circle().fill(.black).frame(width: mood == .surprised ? 5 : 7)
                    .offset(x: 2)
                    .spinning(mood == .surprised ? 1.2 : 3.5)
            }
            .overlay(alignment: .top) {
                if mood == .angry {
                    Rectangle().fill(.black).frame(width: 14, height: 3).offset(y: -4)
                }
            }
        }
    }
}

struct RockView: View {
    let mood: Mood
    var body: some View {
        ZStack {
            RockShape().fill(Color(white: 0.38))
            RockShape().stroke(.black, lineWidth: 3)
            VStack(spacing: 7) {
                HStack(spacing: 12) { Eye(mood: mood); Eye(mood: mood) }
                Mouth(mood: mood)
                    .stroke(.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 9)
            }
            .offset(y: -2)
            if mood == .love || mood == .happy {
                Circle().fill(.red.opacity(0.7)).frame(width: 7).offset(x: 26, y: 6)
            }
        }
    }
}

// MARK: - Сам виджет

struct RockWidgetView: View {
    let entry: RockEntry
    var body: some View {
        Button(intent: PokeRockIntent()) {
            VStack(spacing: 6) {
                RockView(mood: entry.mood)
                    .frame(width: 80, height: 62)
                    .wandering()                          // ← сам двигается постоянно
                    .frame(width: 130, height: 90)        // место, по которому он гуляет
                    .id(entry.mood)                       // смена id → анимация перехода
                    .transition(.push(from: .bottom))
                Text(entry.mood.phrase)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("тыков: \(entry.pokes)")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { Color(white: 0.12) }
    }
}

struct RockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RockWidget", provider: Provider()) { entry in
            RockWidgetView(entry: entry)
        }
        .configurationDisplayName("Камень")
        .description("Тыкай в него.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
