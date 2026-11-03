import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/router/app_router.dart';

void main() {
  test('pay later routes resolve', () {
    expect(AppRouter.payLaterPath, '/app/pay-later');
    String? nameOf(String location) {
      final match = AppRouter.router.configuration.findMatch(
        Uri.parse(location),
      );
      return match.matches.isEmpty
          ? null
          : (match.matches.last.route as dynamic).name as String?;
    }

    expect(nameOf('/app/pay-later'), 'payLater');
    expect(nameOf('/app/pay-later/new?currency=OMR'), 'newPayLaterTab');
    expect(nameOf('/app/pay-later/t1/edit'), 'editPayLaterTab');
    expect(nameOf('/app/pay-later/t1'), 'payLaterTab');
  });
}
