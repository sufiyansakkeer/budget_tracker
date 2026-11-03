import 'package:equatable/equatable.dart';

import '../../../expenses/domain/entities/expense_category.dart';
import '../../domain/entities/pay_later_tab.dart';

enum TabFormStatus { loading, ready, notFound, loadFailed }

class TabFormState extends Equatable {
  final TabFormStatus status;

  /// The tab being edited; null when creating.
  final PayLaterTab? original;

  /// The tab has purchases or payments, so its currency is fixed.
  final bool hasActivity;

  /// Currency a new tab starts with.
  final String defaultCurrency;
  final List<ExpenseCategory> categories;
  final bool saving;

  /// Set once after a successful save.
  final PayLaterTab? saved;

  /// Message for a failed save, shown once.
  final String? saveError;

  const TabFormState({
    this.status = TabFormStatus.loading,
    this.original,
    this.hasActivity = false,
    this.defaultCurrency = 'INR',
    this.categories = const [],
    this.saving = false,
    this.saved,
    this.saveError,
  });

  TabFormState copyWith({
    TabFormStatus? status,
    PayLaterTab? original,
    bool? hasActivity,
    String? defaultCurrency,
    List<ExpenseCategory>? categories,
    bool? saving,
    PayLaterTab? saved,
    String? saveError,
    bool clearSaveError = false,
  }) => TabFormState(
    status: status ?? this.status,
    original: original ?? this.original,
    hasActivity: hasActivity ?? this.hasActivity,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    categories: categories ?? this.categories,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    saveError: clearSaveError ? null : (saveError ?? this.saveError),
  );

  @override
  List<Object?> get props => [
    status,
    original,
    hasActivity,
    defaultCurrency,
    categories,
    saving,
    saved,
    saveError,
  ];
}
