import 'package:equatable/equatable.dart';

import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';

abstract class BillEvent extends Equatable {
  const BillEvent();

  @override
  List<Object?> get props => [];
}

/// Loads all bills from the database.
class BillLoadAll extends BillEvent {
  const BillLoadAll();
}

/// Loads a single bill by id (for details/edit).
class BillLoadById extends BillEvent {
  final String id;

  const BillLoadById(this.id);

  @override
  List<Object?> get props => [id];
}

/// Creates a new bill.
class BillCreate extends BillEvent {
  final BillEntity bill;

  const BillCreate(this.bill);

  @override
  List<Object?> get props => [bill];
}

/// Updates an existing bill.
class BillUpdate extends BillEvent {
  final BillEntity bill;

  const BillUpdate(this.bill);

  @override
  List<Object?> get props => [bill];
}

/// Deletes a bill by id.
class BillDelete extends BillEvent {
  final String id;

  const BillDelete(this.id);

  @override
  List<Object?> get props => [id];
}

/// Marks a bill as paid (or advances if recurring).
class BillMarkPaid extends BillEvent {
  final String billId;

  const BillMarkPaid(this.billId);

  @override
  List<Object?> get props => [billId];
}

/// Marks a paid bill as unpaid.
class BillMarkUnpaid extends BillEvent {
  final String billId;

  const BillMarkUnpaid(this.billId);

  @override
  List<Object?> get props => [billId];
}

/// Changes the active filter.
class BillFilterChanged extends BillEvent {
  final BillFilter filter;

  const BillFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Changes the search query.
class BillSearchChanged extends BillEvent {
  final String query;

  const BillSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Refreshes the bills list.
class BillRefresh extends BillEvent {
  const BillRefresh();
}

/// Clears transient messages.
class BillClearMessage extends BillEvent {
  const BillClearMessage();
}
