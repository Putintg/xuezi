import SwiftUI
import WidgetKit

/// Общая группа с приложением: сюда home_widget пишет список слов.
private let appGroup = "group.app.xuezi.xuezi"

private let paper = Color(red: 0.969, green: 0.949, blue: 0.914)
private let ink = Color(red: 0.122, green: 0.106, blue: 0.086)
private let cinnabar = Color(red: 0.753, green: 0.224, blue: 0.169)
private let muted = Color(red: 0.478, green: 0.435, blue: 0.388)

struct HanziWord: Decodable {
  let h: String
  let p: String
  let m: String

  static let placeholder = HanziWord(h: "学", p: "xué", m: "учиться")
}

struct HanziEntry: TimelineEntry {
  let date: Date
  let word: HanziWord
}

/// Запись словаря words.json, встроенного в виджет.
private struct DictEntry: Decodable {
  let h: String
  let p: String
  let ru: String
  let l: Int
}

/// Запасной вариант без App Group (например, при бесплатном Apple ID):
/// слова HSK 1–2 из словаря, встроенного в сам виджет.
private func bundledWords() -> [HanziWord] {
  guard
    let url = Bundle.main.url(forResource: "words", withExtension: "json"),
    let data = try? Data(contentsOf: url),
    let all = try? JSONDecoder().decode([DictEntry].self, from: data)
  else { return [HanziWord.placeholder] }
  let words = all.filter { $0.l <= 2 }.map { HanziWord(h: $0.h, p: $0.p, m: $0.ru) }
  return words.isEmpty ? [HanziWord.placeholder] : words
}

/// Слова из приложения и длина слота в минутах.
private func loadRotation() -> ([HanziWord], Int) {
  let defaults = UserDefaults(suiteName: appGroup)
  let saved = defaults?.integer(forKey: "slotMinutes") ?? 0
  let slot = saved > 0 ? saved : 120
  guard
    let raw = defaults?.string(forKey: "rotation"),
    let data = raw.data(using: .utf8),
    let words = try? JSONDecoder().decode([HanziWord].self, from: data),
    !words.isEmpty
  else { return (bundledWords(), slot) }
  return (words, slot)
}

/// Слово для момента времени: тот же расчёт, что в Android-виджете.
private func word(at date: Date, _ words: [HanziWord], _ slotMinutes: Int) -> HanziWord {
  let slot = Int(date.timeIntervalSince1970 / 60) / slotMinutes
  return words[slot % words.count]
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> HanziEntry {
    HanziEntry(date: Date(), word: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (HanziEntry) -> Void) {
    let (words, slot) = loadRotation()
    completion(HanziEntry(date: Date(), word: word(at: Date(), words, slot)))
  }

  /// Расписание на сутки вперёд: слово меняется на границе каждого слота.
  func getTimeline(in context: Context, completion: @escaping (Timeline<HanziEntry>) -> Void) {
    let (words, slot) = loadRotation()
    let now = Date()
    let step = TimeInterval(slot * 60)
    let start = (now.timeIntervalSince1970 / step).rounded(.down) * step
    var entries = [HanziEntry(date: now, word: word(at: now, words, slot))]
    var t = start + step
    while t < now.timeIntervalSince1970 + 24 * 3600 {
      let d = Date(timeIntervalSince1970: t)
      entries.append(HanziEntry(date: d, word: word(at: d, words, slot)))
      t += step
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct HanziWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: HanziEntry

  var body: some View {
    switch family {
    case .accessoryInline:
      Text("\(entry.word.h) \(entry.word.p) · \(entry.word.m)")
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        Text(entry.word.h)
          .font(.system(size: entry.word.h.count > 1 ? 18 : 30))
          .minimumScaleFactor(0.5)
      }
    case .accessoryRectangular:
      HStack(spacing: 8) {
        Text(entry.word.h)
          .font(.system(size: 34))
          .minimumScaleFactor(0.4)
          .lineLimit(1)
        VStack(alignment: .leading, spacing: 0) {
          Text(entry.word.p).font(.headline).lineLimit(1)
          Text(entry.word.m).font(.caption).lineLimit(2)
        }
      }
      .widgetAccentable()
    default:
      VStack(spacing: 2) {
        Text(entry.word.h)
          .font(.system(size: family == .systemSmall ? 52 : 64))
          .minimumScaleFactor(0.4)
          .lineLimit(1)
          .foregroundColor(ink)
        Text(entry.word.p)
          .font(.headline)
          .foregroundColor(cinnabar)
        Text(entry.word.m)
          .font(.caption)
          .foregroundColor(muted)
          .multilineTextAlignment(.center)
          .lineLimit(2)
      }
      .padding(8)
    }
  }
}

extension View {
  /// Фон виджета: на iOS 17+ обязателен containerBackground.
  @ViewBuilder func hanziBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { paper }
    } else {
      background(paper)
    }
  }
}

struct HanziWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HanziWidget", provider: Provider()) { entry in
      HanziWidgetView(entry: entry).hanziBackground()
    }
    .configurationDisplayName("Иероглиф")
    .description("Новое слово в течение дня")
    .supportedFamilies([
      .systemSmall, .systemMedium,
      .accessoryRectangular, .accessoryCircular, .accessoryInline,
    ])
  }
}

@main
struct HanziWidgetBundle: WidgetBundle {
  var body: some Widget {
    HanziWidget()
  }
}
