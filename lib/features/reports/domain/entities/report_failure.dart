import 'report_data.dart';

/// Typed errors for the reports module.
enum ReportErrorType { databaseFailure, invalidRange, exportFailure, noData }

/// Failure object for report operations.
class ReportFailure {
  final ReportErrorType type;
  final String message;

  const ReportFailure({required this.type, required this.message});
}

/// Success wrapper for report use case results (mirrors budget/expense errors).
sealed class ReportResult<T> {
  const ReportResult();
}

class ReportSuccess<T> extends ReportResult<T> {
  final T data;

  const ReportSuccess(this.data);
}

class ReportError<T> extends ReportResult<T> {
  final ReportFailure failure;

  const ReportError(this.failure);
}

/// Alias for report data results.
typedef ReportDataResult = ReportResult<ReportData>;
