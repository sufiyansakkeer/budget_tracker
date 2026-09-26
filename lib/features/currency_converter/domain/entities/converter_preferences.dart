import 'package:equatable/equatable.dart';

/// What the converter restores when it is reopened.
class ConverterPreferences extends Equatable {
  final String sourceCode;
  final String targetCode;

  /// The last valid amount, as the user typed it.
  final String amountText;

  const ConverterPreferences({
    required this.sourceCode,
    required this.targetCode,
    required this.amountText,
  });

  /// First-launch pair: the conversion Monivo's users ask for most.
  static const ConverterPreferences defaults = ConverterPreferences(
    sourceCode: 'OMR',
    targetCode: 'INR',
    amountText: '1',
  );

  @override
  List<Object?> get props => [sourceCode, targetCode, amountText];
}
