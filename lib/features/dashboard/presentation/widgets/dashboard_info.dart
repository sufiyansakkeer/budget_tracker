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
          'How much you can spend today in your active budget and still '
          'cover the bills linked to it, the money you keep aside and your '
          'savings goal until the end date. Every budget that is running '
          'today gets its own amount; amounts are never combined.',
      howIsItCalculated:
          'Free to spend = Remaining in budget − Bills due by the end date − '
          'Kept aside − Savings goal\n\n'
          "Today's Safe Spending = Free to spend at the start of today ÷ "
          'Remaining days\n\n'
          'Remaining in budget = Budget amount − all expenses in this '
          'budget.\n'
          'Remaining days = days from today to the end date, counting today.'
          '\n\n'
          "Spent today is this budget's expenses dated today, except "
          'payments of bills that were already set aside. '
          "Left today = Today's Safe Spending − Spent today.",
      example:
          'Budget amount: ${s}30,000\n'
          'Spent before today: ${s}8,000\n'
          'Rent due before the end date: ${s}12,000\n'
          'Kept aside: ${s}2,000\n'
          'Free to spend: ${s}8,000\n'
          'Days left (incl. today): 16\n'
          "Today's Safe Spending: ${s}8,000 ÷ 16 = ${s}500",
      additionalNotes:
          '• The amount stays fixed for the day; expenses you add today '
          'reduce what is left today, and tomorrow is recalculated\n'
          '• Only unpaid bills linked to this budget are set aside. Paying '
          'one with "Mark paid & record expense" doesn\'t use today\'s '
          'amount\n'
          '• Amounts are rounded down, so the figure shown is never more '
          'than is safe\n'
          '• Status: On track; Spend carefully when most of today\'s amount '
          'is used, the forecast is tight or some bills aren\'t included; '
          "Over today's amount; At risk when your average pace would use up "
          'the free money before the end date; Overcommitted when bills and '
          "money set aside are more than what's left; Over budget when more "
          'than the budget amount is spent',
      privacyNote: 'Your financial data is stored locally on your device.',
    );
  }

  static InfoContent freeToSpend(String currency) {
    final s = CurrencyFormatter.symbolFor(currency);
    return InfoContent(
      title: 'Free to spend',
      whatIsThis:
          'What is left in the active budget once the money it must keep '
          'is set aside: unpaid bills linked to it, the amount you keep '
          'aside and your savings goal. Today\'s Safe Spending spreads this '
          'over the days left.',
      howIsItCalculated:
          'Free to spend = Remaining in budget − Bills due − Kept aside − '
          'Savings goal\n\n'
          'Bills due lists every unpaid occurrence of the linked bills up to '
          'the end date, including overdue ones still owed.\n'
          'The forecast takes your average daily spending over the completed '
          'days (bill payments that were set aside are left out) and '
          'projects it to the end date.',
      example:
          'Remaining in budget: ${s}22,000\n'
          '− Bills due: ${s}12,000\n'
          '− Kept aside: ${s}2,000\n'
          '− Savings goal: Not set\n'
          '= Free to spend: ${s}8,000',
      additionalNotes:
          '• "Not set" means you haven\'t set that amount; it is different '
          'from ${s}0\n'
          '• If bills can\'t be loaded, they show as Unavailable and are not '
          'deducted\n'
          '• Bills in another currency are not deducted; change the bill or '
          'the budget to match\n'
          '• The forecast needs a few days of spending first and never '
          "changes today's amount",
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
        "• Another budget is over or near its Today's Safe Spending, or "
        'above its weekly share\n'
        '• The active budget is over its total amount\n'
        "• At your average pace, whether the active budget's free money "
        'lasts until its end date (bills, money kept aside and the savings '
        'goal included)\n'
        '• How much of a budget is used and how many days remain',
    privacyNote: 'All analysis runs on your device. No data leaves your phone.',
  );

  static const InfoContent upcomingBills = InfoContent(
    title: 'Upcoming Bills',
    whatIsThis:
        'Your next unpaid bills that are due today or later, from every '
        'budget.',
    howIsItCalculated:
        'The app lists unpaid bills whose due date is today or in the '
        'future, sorted by due date, and shows the next three.',
    additionalNotes:
        '• Bills linked to a budget are set aside from it until paid\n'
        "• Bills that aren't linked don't affect any budget\n"
        '• Overdue bills are listed in Bills\n'
        '• Mark a bill as paid to remove it from this list',
  );
}
