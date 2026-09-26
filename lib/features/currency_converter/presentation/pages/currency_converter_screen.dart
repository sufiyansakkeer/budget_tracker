import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../../settings/presentation/widgets/currency_selector.dart';
import '../bloc/currency_converter_bloc.dart';
import '../widgets/conversion_result_card.dart';
import '../widgets/converter_amount_field.dart';
import '../widgets/converter_copy.dart';
import '../widgets/currency_pair_card.dart';
import '../widgets/rate_info_card.dart';

/// Converts an amount between any two currencies the rate provider supports.
///
/// The route dispatches [CurrencyConverterStarted] once when it creates the
/// BLoC; nothing here dispatches from `build`, and typing only sends
/// [CurrencyConverterAmountChanged], which never reaches the network.
class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency({required bool source}) async {
    final bloc = context.read<CurrencyConverterBloc>();
    final state = bloc.state;
    final selected = source ? state.source.code : state.target.code;
    final currencies = state.currencies.isEmpty
        ? availableCurrencies
        : state.currencies;
    FocusScope.of(context).unfocus();
    await AppBottomSheet.show<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(
            title: source ? 'Convert from' : 'Convert to',
            subtitle: state.currencyListIsPartial
                ? 'Connect to the internet to see every currency.'
                : '${currencies.length} currencies',
          ),
          CurrencySelector(
            selectedCode: selected,
            currencies: currencies,
            onSelected: (currency) => bloc.add(
              source
                  ? CurrencyConverterSourceSelected(currency.code)
                  : CurrencyConverterTargetSelected(currency.code),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
    // Closing the sheet hands focus back to the amount field, which would
    // pop the keyboard up over the new result. Clear it once that settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _onStateChanged(BuildContext context, CurrencyConverterState state) {
    final bloc = context.read<CurrencyConverterBloc>();
    final notice = state.notice;
    if (notice == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            notice == ConverterNotice.rateUpdated
                ? ConverterCopy.refreshSucceeded
                : ConverterCopy.refreshFailed,
          ),
        ),
      );
    bloc.add(const CurrencyConverterNoticeCleared());
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CurrencyConverterBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Currency converter')),
      body: MultiBlocListener(
        listeners: [
          // The saved amount arrives after the first frame; copy it into the
          // field once. Later amount changes come *from* the field.
          BlocListener<CurrencyConverterBloc, CurrencyConverterState>(
            listenWhen: (prev, curr) => !prev.isRestored && curr.isRestored,
            listener: (context, state) =>
                _amountController.text = state.amountText,
          ),
          BlocListener<CurrencyConverterBloc, CurrencyConverterState>(
            listenWhen: (prev, curr) =>
                prev.notice != curr.notice && curr.notice != null,
            listener: _onStateChanged,
          ),
        ],
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: ListView(
            padding: AppSpacing.pagePadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _amountSection(bloc),
                      const SizedBox(height: AppSpacing.md),
                      _pairSection(bloc),
                      const SizedBox(height: AppSpacing.md),
                      _resultSection(bloc),
                      const SizedBox(height: AppSpacing.md),
                      _rateSection(bloc),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountSection(CurrencyConverterBloc bloc) {
    return BlocBuilder<CurrencyConverterBloc, CurrencyConverterState>(
      buildWhen: (prev, curr) =>
          prev.source != curr.source || prev.amountError != curr.amountError,
      builder: (context, state) => ConverterAmountField(
        controller: _amountController,
        symbol: state.source.symbol,
        currencyCode: state.source.code,
        error: state.amountError,
        onChanged: (text) => bloc.add(CurrencyConverterAmountChanged(text)),
      ),
    );
  }

  Widget _pairSection(CurrencyConverterBloc bloc) {
    return BlocBuilder<CurrencyConverterBloc, CurrencyConverterState>(
      buildWhen: (prev, curr) =>
          prev.source != curr.source ||
          prev.target != curr.target ||
          prev.swapCount != curr.swapCount,
      builder: (context, state) => CurrencyPairCard(
        source: state.source,
        target: state.target,
        swapCount: state.swapCount,
        onPickSource: () => _pickCurrency(source: true),
        onPickTarget: () => _pickCurrency(source: false),
        onSwap: () => bloc.add(const CurrencyConverterSwapped()),
      ),
    );
  }

  Widget _resultSection(CurrencyConverterBloc bloc) {
    return BlocBuilder<CurrencyConverterBloc, CurrencyConverterState>(
      buildWhen: (prev, curr) =>
          prev.result != curr.result ||
          prev.amount != curr.amount ||
          prev.rate != curr.rate ||
          prev.rateFailure != curr.rateFailure ||
          prev.source != curr.source ||
          prev.target != curr.target,
      builder: (context, state) => ConversionResultCard(
        source: state.source,
        target: state.target,
        amount: state.amount,
        result: state.result,
        rate: state.rate,
        failure: state.rateStatus == RateStatus.error
            ? state.rateFailure
            : null,
        onRetry: () => bloc.add(const CurrencyConverterRetried()),
      ),
    );
  }

  Widget _rateSection(CurrencyConverterBloc bloc) {
    return BlocBuilder<CurrencyConverterBloc, CurrencyConverterState>(
      buildWhen: (prev, curr) =>
          prev.rate != curr.rate ||
          prev.isRefreshing != curr.isRefreshing ||
          prev.target != curr.target,
      builder: (context, state) {
        final lookup = state.rate;
        if (lookup == null) return const SizedBox.shrink();
        return RateInfoCard(
          lookup: lookup,
          target: state.target,
          isRefreshing: state.isRefreshing,
          onRefresh: () => bloc.add(const CurrencyConverterRateRefreshed()),
        );
      },
    );
  }
}
