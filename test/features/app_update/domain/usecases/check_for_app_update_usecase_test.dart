import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/app_update/domain/usecases/check_for_app_update_usecase.dart';

void main() {
  group('CheckForAppUpdateUseCase.compareVersions', () {
    test('1.0.0 vs 1.0.0 → equal', () {
      expect(CheckForAppUpdateUseCase.compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('1.0.0 vs 1.0.1 → current is older', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.0.0', '1.0.1'),
        lessThan(0),
      );
    });

    test('1.0.1 vs 1.0.0 → current is newer', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.0.1', '1.0.0'),
        greaterThan(0),
      );
    });

    test('1.1.0 vs 1.0.9 → current is newer', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.1.0', '1.0.9'),
        greaterThan(0),
      );
    });

    test('1.10.0 vs 1.9.0 → current is newer (numeric, not lexical)', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.10.0', '1.9.0'),
        greaterThan(0),
      );
    });

    test('1.9.0 vs 1.10.0 → current is older', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.9.0', '1.10.0'),
        lessThan(0),
      );
    });

    test('v1.0.0 vs 1.0.1 → current is older (strips v prefix)', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('v1.0.0', '1.0.1'),
        lessThan(0),
      );
    });

    test('1.0.0 vs v1.1.0 → current is older', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.0.0', 'v1.1.0'),
        lessThan(0),
      );
    });

    test('v1.2.0 vs 1.3.0 → current is older', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('v1.2.0', '1.3.0'),
        lessThan(0),
      );
    });

    test('1.3.0 vs v1.4.0 → current is older', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.3.0', 'v1.4.0'),
        lessThan(0),
      );
    });

    test('1.2.0+15 vs 1.2.0 → equal (strips build metadata)', () {
      expect(CheckForAppUpdateUseCase.compareVersions('1.2.0+15', '1.2.0'), 0);
    });

    test('2.0.0 vs 1.0.0 → current is newer', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('2.0.0', '1.0.0'),
        greaterThan(0),
      );
    });

    test('1.0.0 vs 2.0.0 → current is older', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.0.0', '2.0.0'),
        lessThan(0),
      );
    });

    test('handles missing patch version: 1.0 vs 1.0.1', () {
      expect(
        CheckForAppUpdateUseCase.compareVersions('1.0', '1.0.1'),
        lessThan(0),
      );
    });

    test('handles different segment counts: 1.0 vs 1.0.0', () {
      expect(CheckForAppUpdateUseCase.compareVersions('1.0', '1.0.0'), 0);
    });
  });
}
