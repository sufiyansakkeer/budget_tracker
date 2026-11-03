import '../entities/pay_later_failure.dart';
import '../entities/pay_later_tab.dart';
import '../entities/tab_ledger.dart';
import 'get_tab_ledger_usecase.dart';
import 'get_tabs_usecase.dart';

/// The ledger of every tab [where] accepts (all tabs by default), through
/// the existing use cases so each one is built exactly as the tab screen
/// builds it. A tab removed between the two reads is skipped; any other
/// failure fails the whole load, so a total is never shown short.
Future<PayLaterResult<List<TabLedger>>> loadTabLedgers({
  required GetTabsUseCase getTabs,
  required GetTabLedgerUseCase getLedger,
  bool Function(PayLaterTab tab)? where,
}) async {
  final tabsResult = await getTabs();
  final List<PayLaterTab> tabs;
  switch (tabsResult) {
    case PayLaterError(:final failure):
      return PayLaterError(failure);
    case PayLaterSuccess(:final data):
      tabs = data;
  }
  final ledgers = <TabLedger>[];
  for (final tab in tabs) {
    if (where != null && !where(tab)) continue;
    switch (await getLedger(tab.id)) {
      case PayLaterSuccess(:final data):
        ledgers.add(data);
      case PayLaterError(:final failure)
          when failure.type == PayLaterErrorType.notFound:
        continue;
      case PayLaterError(:final failure):
        return PayLaterError(failure);
    }
  }
  return PayLaterSuccess(ledgers);
}
