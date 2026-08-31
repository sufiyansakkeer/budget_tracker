import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

/// Provides timeline entries for the Monivo spending widget.
/// Data is read from shared UserDefaults (App Group container).
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(
            date: Date(),
            dailySafeSpending: 0,
            spentToday: 0,
            remainingBudget: 0,
            remainingDays: 0,
            currency: "INR",
            status: "on_track",
            hasActiveBudget: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh the widget every hour. The Dart side also pushes
        // updates via HomeWidget.updateWidget() after data changes.
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> SpendingEntry {
        let defaults = UserDefaults(suiteName: "group.com.sufiyan.monivo")
            ?? UserDefaults.standard

        let hasBudget = defaults.string(forKey: "home_widget_has_budget") == "true"
        let dailySafe = defaults.string(forKey: "home_widget_daily_safe")
            .flatMap(Double.init) ?? 0
        let spentToday = defaults.string(forKey: "home_widget_spent_today")
            .flatMap(Double.init) ?? 0
        let remaining = defaults.string(forKey: "home_widget_remaining")
            .flatMap(Double.init) ?? 0
        let remainingDays = defaults.string(forKey: "home_widget_remaining_days")
            .flatMap(Int.init) ?? 0
        let currency = defaults.string(forKey: "home_widget_currency") ?? "INR"
        let status = defaults.string(forKey: "home_widget_status") ?? "no_budget"

        return SpendingEntry(
            date: Date(),
            dailySafeSpending: dailySafe,
            spentToday: spentToday,
            remainingBudget: remaining,
            remainingDays: remainingDays,
            currency: currency,
            status: status,
            hasActiveBudget: hasBudget
        )
    }
}

// MARK: - Timeline Entry

struct SpendingEntry: TimelineEntry {
    let date: Date
    let dailySafeSpending: Double
    let spentToday: Double
    let remainingBudget: Double
    let remainingDays: Int
    let currency: String
    let status: String
    let hasActiveBudget: Bool
}

// MARK: - Currency Formatting

struct CurrencyHelper {
    static func symbol(for code: String) -> String {
        switch code {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "AED": return "د.إ"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "SGD": return "S$"
        default: return "₹"
        }
    }

    static func format(_ amount: Double, code: String) -> String {
        let sym = symbol(for: code)
        return "\(sym)\(Int(amount).formatted())"
    }
}

// MARK: - Widget Entry View

struct MonivoWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if !entry.hasActiveBudget {
                emptyStateView
            } else {
                spendingView
            }
        }
        .widgetURL(URL(string: "monivo:///app/home"))
    }


    // MARK: - Spending View

    private var spendingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("Smart Budget Tracker")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            // Safe Spending
            Text("Today's Safe Spending")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            Text(CurrencyHelper.format(entry.dailySafeSpending, code: entry.currency))
                .font(.system(size: family == .systemSmall ? 22 : 28, weight: .bold))
                .foregroundStyle(statusColor)
                .padding(.bottom, 8)

            // Spent Today
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent Today")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(CurrencyHelper.format(entry.spentToday, code: entry.currency))
                        .font(.system(size: 16, weight: .bold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Status")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(statusLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(statusColor)
                }
            }
            .padding(.bottom, 6)

            Spacer(minLength: 0)

            // Quick action button
            Link(destination: URL(string: "monivo:///app/expenses/add")!) {
                HStack {
                    Spacer()
                    Text("+ Add Expense")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(Color(red: 0.11, green: 0.37, blue: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "wallet.pass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Smart Budget Tracker")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
            Text("Open app to set up a budget")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Link(destination: URL(string: "monivo:///app/expenses/add")!) {
                HStack {
                    Spacer()
                    Text("+ Add Expense")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(Color(red: 0.11, green: 0.37, blue: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
    }


    // MARK: - Helpers

    private var statusColor: Color {
        if entry.status.hasPrefix("over:") {
            return .red
        } else if entry.status == "on_track" {
            return .green
        } else {
            return .gray
        }
    }

    private var statusLabel: String {
        if entry.status.hasPrefix("over:") {
            let amount = entry.status
                .replacingOccurrences(of: "over:", with: "")
                .flatMap(Double.init) ?? 0
            return "\(CurrencyHelper.format(amount, code: entry.currency)) over"
        } else if entry.status == "on_track" {
            return "On Track"
        } else if entry.status == "no_budget" {
            return "No Budget"
        } else {
            return "Open app to refresh"
        }
    }
}

// MARK: - Widget Configuration

struct MonivoWidget: Widget {
    let kind: String = "MonivoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MonivoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Budget Tracker")
        .description("Shows your daily safe spending and budget status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle (for multiple widgets)

@main
struct MonivoWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonivoWidget()
    }
}
