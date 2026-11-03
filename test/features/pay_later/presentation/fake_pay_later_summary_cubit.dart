import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_overview.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_summary_cubit.dart';

/// Holds one summary (default none, so Home's Pay later row is hidden);
/// never reads anything.
class FakePayLaterSummaryCubit extends Cubit<PayLaterOverview?>
    implements PayLaterSummaryCubit {
  FakePayLaterSummaryCubit([super.initial]);

  @override
  Future<void> load() async {}
}
