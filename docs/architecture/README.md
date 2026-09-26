# Architecture notes

Short, specific documents about how Smart Monivo is put together and why.
Each one answers a question a new contributor (or a future maintainer) will
actually ask.

| Document | Question it answers |
| --- | --- |
| [decisions.md](decisions.md) | Why Drift, BLoC, Clean Architecture and GetIt? |
| [safe_spending.md](safe_spending.md) | How is Today's Safe Spending calculated, and why that formula? |
| [multiple_budgets.md](multiple_budgets.md) | How do independent budgets work, and what is never shared between them? |
| [rive_navigation.md](rive_navigation.md) | How does the animated bottom navigation work, and how do I change its icons? |
| [offline_first.md](offline_first.md) | What does "offline-first" mean here, and what is the data contract? |
| [notifications.md](notifications.md) | What is scheduled, when, and what keeps it accurate? |
| [backup_restore.md](backup_restore.md) | What exactly is exported, backed up and restored? |

The calculation rules that the budget engine implements live next to the code
they describe: [`lib/features/budget/CALCULATION_RULES.md`](../../lib/features/budget/CALCULATION_RULES.md).
