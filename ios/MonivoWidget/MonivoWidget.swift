import SwiftUI
import UIKit
import WidgetKit

// The home-screen widget: Today's Safe Spending for the active budget.
//
// The Flutter app works out and formats everything and stores it as one JSON
// payload (lib/features/widgets/home_widget_payload.dart) in the App Group's
// UserDefaults. This extension never formats money or recomputes a budget; it
// decides what to show for the day and lays it out for the widget's size and
// the user's text size.

// MARK: - Payload

struct WidgetPayload: Decodable {
    let v: Int
    let state: String
    /// The day the figures are for, yyyy-MM-dd in local time.
    let asOf: String
    let colors: PaletteColors?
    let stale: WidgetMessage
    let label: String?
    let shortLabel: String?
    let safe: Money?
    let status: Status?
    let today: Today?
    let budget: Budget?
    let summary: String?
    let message: WidgetMessage?

    static let key = "home_widget_payload"
    static let version = 2

    static func load() -> WidgetPayload? {
        let defaults = UserDefaults(suiteName: "group.com.sufiyan.monivo") ?? .standard
        guard let raw = defaults.string(forKey: key), let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data),
              payload.v == version
        else { return nil }
        return payload
    }

    struct Money: Decodable {
        let text: String
        let spoken: String
        let sign: String
        let prefix: String
        let whole: String
        let fraction: String
        let suffix: String
    }

    struct Status: Decodable {
        let label: String
        let tone: String
    }

    struct Today: Decodable {
        let progress: Double
        let spentLabel: String
        let spent: String
        let restLabel: String
        let rest: String
    }

    struct Budget: Decodable {
        let name: String
        let daysLeft: String
        let left: String
        let progress: Double
        let tone: String
    }
}

struct WidgetMessage: Decodable {
    let title: String
    let body: String
    let short: String?

    var shortTitle: String { short ?? title }

    static let setup = WidgetMessage(
        title: "Open Monivo",
        body: "Open the app to set up this widget.",
        short: nil
    )
}

/// The palette's colours for light and dark, as the app ships them.
struct PaletteColors: Decodable {
    let light: [String: String]
    let dark: [String: String]

    /// Monivo's Default palette, until the app has written the user's.
    static let fallback = PaletteColors(
        light: [
            "surface": "#FFFFFFFF", "ink": "#FF17191F", "muted": "#FF66676A",
            "track": "#FFDBDBDB", "accent": "#FF3155D4", "onAccent": "#FFFFFFFF",
            "divider": "#FFCCCCCE", "positive": "#FF1E724D", "caution": "#FF8C591C",
            "critical": "#FFBC2D35", "neutral": "#FF66676A",
        ],
        dark: [
            "surface": "#FF222229", "ink": "#FFF2F2F6", "muted": "#FFA4A4A8",
            "track": "#FF42424E", "accent": "#FF869DEC", "onAccent": "#FF0B1947",
            "divider": "#FF454549", "positive": "#FF5EC999", "caution": "#FFDEB17C",
            "critical": "#FFEA878B", "neutral": "#FFA4A4A8",
        ]
    )

    /// A colour that follows the system appearance.
    func color(_ name: String) -> Color {
        let day = Self.uiColor(light[name] ?? Self.fallback.light[name] ?? "#FF808080")
        let night = Self.uiColor(dark[name] ?? Self.fallback.dark[name] ?? "#FF808080")
        return Color(UIColor { $0.userInterfaceStyle == .dark ? night : day })
    }

    func tone(_ name: String?) -> Color {
        switch name {
        case "positive", "caution", "critical": return color(name!)
        default: return color("neutral")
        }
    }

    /// "#AARRGGBB".
    private static func uiColor(_ hex: String) -> UIColor {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xFF80_8080
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat((value >> 24) & 0xFF) / 255
        )
    }
}

// MARK: - What to show

enum WidgetContent {
    case figures(WidgetPayload)
    case message(WidgetMessage)

    /// The figures or message for the entry's day; once the day has turned
    /// since the app last wrote, a request to open it instead of yesterday's
    /// amount shown as today's.
    static func resolve(_ payload: WidgetPayload?, on date: Date) -> WidgetContent {
        guard let payload else { return .message(.setup) }
        if payload.asOf != dayFormatter.string(from: date) { return .message(payload.stale) }
        if payload.state == "ready", payload.safe != nil { return .figures(payload) }
        return .message(payload.message ?? .setup)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Timeline

struct SpendingEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload?

    var content: WidgetContent { .resolve(payload, on: date) }
    var colors: PaletteColors { payload?.colors ?? .fallback }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(date: Date(), payload: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        completion(SpendingEntry(date: Date(), payload: WidgetPayload.load()))
    }

    /// Now, and again just after midnight, when the figures turn into a
    /// request to open the app. The app also reloads the widget whenever its
    /// data changes, so there is no polling.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let now = Date()
        let payload = WidgetPayload.load()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let entries = [
            SpendingEntry(date: now, payload: payload),
            SpendingEntry(date: midnight.addingTimeInterval(5), payload: payload),
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

struct MonivoWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetBody(content: entry.content, colors: entry.colors, family: family)
            .widgetSurface(entry.colors.color("surface"))
            .widgetURL(Links.home)
    }
}

enum Links {
    static let home = URL(string: "monivo:///app/home")!
    static let addExpense = URL(string: "monivo:///app/expenses/add")!
}

/// The widget's content for one family. Each family lists its layouts
/// richest first; the first that fits the space at the user's text size is
/// used. Content priority: the amount; what it is and its status; today's
/// spending against it; the budget; Add expense.
struct WidgetBody: View {
    let content: WidgetContent
    let colors: PaletteColors
    let family: WidgetFamily

    var body: some View {
        switch content {
        case .figures(let payload):
            // The figures read as one sentence; Add expense stays its own
            // button beside them.
            let figures = Figures(p: payload, colors: colors, family: family)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(payload.summary ?? payload.safe?.spoken ?? "")
            switch family {
            case .systemSmall:
                // Small widgets have one tap target: the whole widget.
                figures.frame(maxHeight: .infinity, alignment: .top)
            case .systemMedium:
                figures.frame(maxHeight: .infinity, alignment: .top)
                    .overlay(alignment: .topTrailing) { AddButton(colors: colors, compact: true) }
            default:
                VStack(spacing: 12) {
                    figures.frame(maxHeight: .infinity, alignment: .top)
                    AddButton(colors: colors, compact: false)
                }
            }
        case .message(let message):
            Message(message: message, colors: colors, family: family)
        }
    }
}

// MARK: Figures

private struct Figures: View {
    let p: WidgetPayload
    let colors: PaletteColors
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            Fitting {
                VStack(alignment: .leading, spacing: 4) {
                    label(short: true); amount(.title); statusLine
                    track.padding(.top, 6)
                    InlineMetric(label: p.today?.restLabel, value: p.today?.rest, colors: colors)
                }
                VStack(alignment: .leading, spacing: 4) { label(short: true); amount(.title); statusLine }
                VStack(alignment: .leading, spacing: 2) { label(short: true); amount(.title) }
                amount(.title)
            }
        case .systemMedium:
            // The Add button sits over the top-right corner; the top block
            // keeps that corner free.
            Fitting {
                VStack(alignment: .leading, spacing: 4) {
                    beside(button: VStack(alignment: .leading, spacing: 0) { label(short: false); amount(.largeTitle) })
                    budgetStatusLine
                    track.padding(.top, 4)
                    HStack(spacing: 8) {
                        InlineMetric(label: p.today?.spentLabel, value: p.today?.spent, colors: colors)
                        Spacer(minLength: 0)
                        InlineMetric(label: p.today?.restLabel, value: p.today?.rest, colors: colors)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    beside(button: VStack(alignment: .leading, spacing: 0) { label(short: true); amount(.largeTitle) })
                    statusLine
                    InlineMetric(label: p.today?.restLabel, value: p.today?.rest, colors: colors)
                }
                VStack(alignment: .leading, spacing: 4) {
                    beside(button: VStack(alignment: .leading, spacing: 0) { label(short: true); amount(.largeTitle) })
                    statusLine
                }
                beside(button: VStack(alignment: .leading, spacing: 0) { label(short: true); amount(.largeTitle) })
                beside(button: amount(.largeTitle))
            }
        default:
            Fitting {
                large
                VStack(alignment: .leading, spacing: 4) {
                    label(short: false); amount(.largeTitle); budgetStatusLine
                    track.padding(.top, 8)
                    metrics.padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    label(short: true); amount(.largeTitle); statusLine
                    InlineMetric(label: p.today?.restLabel, value: p.today?.rest, colors: colors)
                }
                VStack(alignment: .leading, spacing: 4) { label(short: true); amount(.largeTitle); statusLine }
                amount(.largeTitle)
            }
        }
    }

    /// [content] with the top-right corner kept free for the Add button.
    private func beside<Content: View>(button content: Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            content
            Spacer(minLength: 0)
            Color.clear.frame(width: 40, height: 40)
        }
    }

    /// "On track · Food".
    private var budgetStatusLine: some View {
        HStack(spacing: 6) {
            statusLine
            Text(ltr: "· \(p.budget?.name ?? "")")
                .font(.footnote)
                .foregroundStyle(colors.color("muted"))
                .lineLimit(1)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(ltr: p.budget?.name ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.color("ink"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(ltr: p.budget?.daysLeft ?? "")
                    .font(.footnote)
                    .foregroundStyle(colors.color("muted"))
                    .lineLimit(1)
            }
            label(short: false).padding(.top, 8)
            amount(.largeTitle, scale: 1.25)
            statusLine
            track.padding(.top, 10)
            metrics.padding(.top, 4)
            Rectangle().fill(colors.color("divider")).frame(height: 1).padding(.vertical, 8)
            Text(ltr: p.budget?.left ?? "")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(colors.color("ink"))
                .fixedSize(horizontal: false, vertical: true)
            Track(value: p.budget?.progress ?? 0, fill: colors.tone(p.budget?.tone), track: colors.color("track"), height: 4)
                .padding(.top, 4)
        }
    }

    /// The label with the status dot set inline, so it wraps with the text.
    private func label(short: Bool) -> some View {
        (Text("\u{25CF}")
            .foregroundColor(colors.tone(p.status?.tone))
            + Text("  " + ((short ? p.shortLabel : p.label) ?? ""))
            .foregroundColor(colors.color("muted")))
            .font(.subheadline.weight(.medium))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func amount(_ style: Font.TextStyle, scale: CGFloat = 1) -> some View {
        Amount(money: p.safe!, style: style, scale: scale, color: colors.color("ink"))
    }

    private var statusLine: some View {
        Text(ltr: p.status?.label ?? "")
            .font(.footnote.weight(.medium))
            .foregroundStyle(colors.color("ink"))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var track: some View {
        Track(value: p.today?.progress ?? 0, fill: colors.tone(p.status?.tone), track: colors.color("track"), height: 6)
    }

    private var rest: some View {
        Metric(label: p.today?.restLabel ?? "", value: p.today?.rest ?? "", colors: colors, alignment: .leading)
    }

    /// Spent and left today side by side, or one above the other when they
    /// don't fit, so neither figure is cut.
    private var metrics: some View {
        let spent = Metric(label: p.today?.spentLabel ?? "", value: p.today?.spent ?? "", colors: colors, alignment: .leading)
        let rest = { (alignment: HorizontalAlignment) in
            Metric(label: p.today?.restLabel ?? "", value: p.today?.rest ?? "", colors: colors, alignment: alignment)
        }
        return Fitting(axis: .horizontal) {
            HStack(alignment: .top) { spent; Spacer(minLength: 12); rest(.trailing) }
            VStack(alignment: .leading, spacing: 6) { spent; rest(.leading) }
            VStack(alignment: .leading, spacing: 6) { spent; rest(.leading) }.minimumScaleFactor(0.5)
        }
    }
}

/// The hero figure the app's way: the symbol and minor units at half size.
/// It never truncates: when the whole figure doesn't fit at its size it is
/// set smaller, then in whole units (a floored safe amount, so dropping the
/// minor units never promises more), and only then scaled down.
private struct Amount: View {
    let money: WidgetPayload.Money
    let style: Font.TextStyle
    let scale: CGFloat
    let color: Color

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let size = UIFont.preferredFont(forTextStyle: style.uiKit, compatibleWith: UITraitCollection(preferredContentSizeCategory: typeSize.uiKit)).pointSize * scale
        if #available(iOS 16.0, *) {
            Fitting(axis: .horizontal) {
                figure(size: size, fraction: true)
                figure(size: size * 0.8, fraction: true)
                // Last resort, so it may shrink a long way rather than be cut.
            figure(size: size * 0.8, fraction: false).minimumScaleFactor(0.25)
            }
        } else {
            figure(size: size, fraction: true).minimumScaleFactor(0.5)
        }
    }

    private func figure(size: CGFloat, fraction: Bool) -> some View {
        let big = Font.system(size: size, weight: .bold).monospacedDigit()
        let small = Font.system(size: size * 0.5, weight: .bold).monospacedDigit()
        var text = Text(ltr: money.sign).font(big) + Text(money.prefix).font(small) + Text(money.whole).font(big)
        if fraction { text = text + Text(money.fraction).font(small) }
        text = text + Text(money.suffix).font(small)
        return text.foregroundStyle(color).lineLimit(1)
    }
}

private struct Metric: View {
    let label: String
    let value: String
    let colors: PaletteColors
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(ltr: label).font(.caption).foregroundStyle(colors.color("muted")).lineLimit(1)
            Text(ltr: value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(colors.color("ink")).lineLimit(1)
        }
    }
}

/// "Left today ₹587.50" on one line, for the compact layouts; stacked when
/// that line doesn't fit, so the figure is never cut.
private struct InlineMetric: View {
    let label: String?
    let value: String?
    let colors: PaletteColors

    var body: some View {
        Fitting(axis: .horizontal) {
            (Text(ltr: (label ?? "") + " ").foregroundColor(colors.color("muted"))
                + Text(value ?? "").fontWeight(.semibold).foregroundColor(colors.color("ink")))
                .font(.footnote)
                .monospacedDigit()
                .lineLimit(1)
            stacked
            stacked.minimumScaleFactor(0.6)
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ltr: label ?? "").font(.footnote).foregroundColor(colors.color("muted")).lineLimit(1)
            Text(ltr: value ?? "").font(.footnote.weight(.semibold)).monospacedDigit()
                .foregroundColor(colors.color("ink")).lineLimit(1)
        }
    }
}

private struct Track: View {
    let value: Double
    let fill: Color
    let track: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if value > 0 {
                    Capsule().fill(fill)
                        .frame(width: max(height, geo.size.width * min(1, value)))
                        .accentable()
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct AddButton: View {
    let colors: PaletteColors
    let compact: Bool

    var body: some View {
        Link(destination: Links.addExpense) {
            if compact {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(colors.color("onAccent"))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(colors.color("accent")))
            } else {
                Label("Add expense", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.color("onAccent"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(colors.color("accent")))
                    // Large enough to read, small enough to leave the
                    // figures their room.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .accessibilityLabel("Add expense")
    }
}

// MARK: Messages

private struct Message: View {
    let message: WidgetMessage
    let colors: PaletteColors
    let family: WidgetFamily

    var body: some View {
        Fitting {
            full(button: family != .systemSmall)
            full(button: false)
            title(message.title)
            title(message.shortTitle).minimumScaleFactor(0.5)
        }
    }

    private func full(button: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                title(message.title)
                Text(ltr: message.body)
                    .font(.subheadline)
                    .foregroundStyle(colors.color("muted"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if button {
                Spacer(minLength: 8)
                AddButton(colors: colors, compact: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ text: String) -> some View {
        Text(ltr: text)
            .font(.headline)
            .foregroundStyle(colors.color("ink"))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helpers

/// The first of its views that fits (ViewThatFits on iOS 16+). iOS 15 has no
/// way to measure, so it picks by text size: the first layout up to xxLarge,
/// the next-to-last above it.
private struct Fitting<A: View, B: View, C: View, D: View, E: View>: View {
    let axis: Axis.Set
    let count: Int
    let a: A, b: B, c: C, d: D, e: E

    init(axis: Axis.Set = .vertical, @ViewBuilder _ views: () -> TupleView<(A, B, C)>)
    where D == EmptyView, E == EmptyView {
        self.axis = axis
        count = 3
        (a, b, c) = views().value
        d = EmptyView(); e = EmptyView()
    }

    init(axis: Axis.Set = .vertical, @ViewBuilder _ views: () -> TupleView<(A, B, C, D)>)
    where E == EmptyView {
        self.axis = axis
        count = 4
        (a, b, c, d) = views().value
        e = EmptyView()
    }

    init(axis: Axis.Set = .vertical, @ViewBuilder _ views: () -> TupleView<(A, B, C, D, E)>) {
        self.axis = axis
        count = 5
        (a, b, c, d, e) = views().value
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if #available(iOS 16.0, *) {
            switch count {
            case 3: ViewThatFits(in: axis) { a; b; c }
            case 4: ViewThatFits(in: axis) { a; b; c; d }
            default: ViewThatFits(in: axis) { a; b; c; d; e }
            }
        } else if typeSize >= .xxxLarge {
            switch count {
            case 3: b
            case 4: c
            default: d
            }
        } else {
            a
        }
    }
}

private extension View {
    /// The widget's background: the palette surface, with iOS 17's system
    /// margins, or this padding before iOS 17.
    @ViewBuilder
    func widgetSurface(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(color)
        }
    }

    /// Tinted in the accented and vibrant renderings (iOS 16+).
    @ViewBuilder
    func accentable() -> some View {
        if #available(iOS 16.0, *) { widgetAccentable() } else { self }
    }
}

private extension Text {
    /// Text set left to right, like the app: a figure that starts with an
    /// Arabic-script currency symbol (ر.ع.) would otherwise turn the whole
    /// line right to left and move the symbol after the digits.
    init(ltr text: String) {
        self.init(verbatim: "\u{200E}" + text)
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

private extension DynamicTypeSize {
    var uiKit: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

// MARK: - Widget Configuration

struct MonivoWidget: Widget {
    let kind: String = "MonivoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MonivoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Monivo")
        .description("Today's safe spending for your active budget, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle (for multiple widgets)

@main
struct MonivoWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonivoWidget()
    }
}
