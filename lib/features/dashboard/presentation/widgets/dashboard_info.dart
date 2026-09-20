import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';

/// Explanation content for dashboard metrics. Examples use the budget's own
/// currency symbol so they read naturally for every user.
class DashboardInfo {
  DashboardInfo._();

  static InfoContent safeSpending(String currency) {
    final s = CurrencyFormatter.symbolFor(currency);
    return InfoContent(
      title: "Today's Safe Spending",
      whatIsThis:
          'How much you can still spend today while staying within your '
          'active budget for the rest of its period. Every budget that is '
          'running today gets its own amount; amounts are never combined.',
      howIsItCalculated:
          "Today's Safe Spending = Remaining budget at the start of today ÷ "
          'Remaining days\n\n'
          'Remaining budget at the start of today = Budget amount − all '
          'expenses before today.\n'
          'Remaining days = days from today to the end date, counting today.\n\n'
          "Spent today is the total of this budget's expenses dated today. "
          "Left today = Today's Safe Spending − Spent today.",
      example:
          'Budget amount: ${s}10,000\n'
          'Spent before today: ${s}2,000\n'
          'Days left (incl. today): 20\n'
          "Today's Safe Spending: ${s}8,000 ÷ 20 = ${s}400",
      additionalNotes:
          '• The amount stays fixed for the day; expenses you add today '
          'reduce what is left today, and tomorrow is recalculated\n'
          '• Spending less leaves more for the remaining days; spending more '
          'leaves less\n'
          '• Status: On track below 80% of the safe amount, Near limit at '
          '80–100%, Over limit above 100%',
      privacyNote: 'Your financial data is stored locally on your device.',
    );
  }

  static InfoContent budgetOverview(String currency) {
    final s = CurrencyFormatter.symbolFor(currency);
    return InfoContent(
      title: 'Budget Overview',
      whatIsThis:
          'How much of your active budget is still available for the rest of '
          'its period, how much of it you have used, and where today falls '
          'in the budget period.',
      howIsItCalculated:
          'Remaining = Budget amount − Total spent\n'
          'Used = Total spent ÷ Budget amount\n'
          'Days left = days from today to the end date, counting today.',
      example:
          'Budget amount: ${s}30,000\n'
          'Total spent: ${s}9,000\n'
          'Remaining: ${s}21,000 · Used: 30%',
      additionalNotes:
          '• Shows the active budget only; switch budgets at the top of the '
          'Dashboard\n'
          '• Each budget has its own amount, period and expenses; they are '
          'not combined here\n'
          '• Remaining can be negative if you have spent more than the '
          'budget amount',
    );
  }

  static const InfoContent smartInsights = InfoContent(
    title: 'Smart Insights',
    whatIsThis:
        'Short, rule-based messages generated from your budgets and '
        'expenses. They are simple calculations, not AI, and never use data '
        'from outside the app.',
    howIsItCalculated:
        'Each active budget is checked against fixed rules, and up to three '
        'of the most important messages are shown. Messages about your '
        'active budget use its own amount, dates and expenses.',
    additionalNotes:
        'Insights you may see:\n'
        "• A budget is over or near Today's Safe Spending\n"
        '• The active budget is over its total amount\n'
        '• At the current pace, the active budget may end the period over '
        'its amount\n'
        "• A budget's spending this week (Monday to Sunday) is above its "
        'weekly share\n'
        '• How much of a budget is used and how many days remain\n'
        "• Your average daily spending compared with Today's Safe Spending\n"
        '• The amount the active budget is expected to have left at the end '
        'of its period',
    privacyNote: 'All analysis runs on your device. No data leaves your phone.',
  );

  static const InfoContent upcomingBills = InfoContent(
    title: 'Upcoming Bills',
    whatIsThis:
        'Your next unpaid bills that are due today or later. Bills are '
        'tracked separately from your budgets and expenses.',
    howIsItCalculated:
        'The app lists unpaid bills whose due date is today or in the '
        'future, sorted by due date, and shows the next three.',
    additionalNotes:
        '• Overdue bills are not shown here. Open Bills to see them\n'
        '• Mark a bill as paid to remove it from this list\n'
        '• A bill only affects a budget if you record it as an expense '
        '(Mark Paid & Add Expense)\n'
        '• Bills are shared across all budgets',
  );
}
