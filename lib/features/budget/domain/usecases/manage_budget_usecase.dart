import '../../../../core/domain/entities/budget_entity.dart';
import '../entities/budget_filter.dart';
import '../repository/budget_repository.dart';

/// Aggregates CRUD, archive, duplicate, and active-budget operations for the
/// multi-budget system. Screens use this single use case to avoid proliferating
/// tiny use-case classes.
class ManageBudgetUseCase {
  final BudgetRepository repository;

  ManageBudgetUseCase({required this.repository});

  Future<BudgetEntity> create(BudgetEntity budget) {
    return repository.createBudget(budget);
  }

  Future<BudgetEntity> update(BudgetEntity budget) {
    return repository.updateBudget(budget);
  }

  Future<void> delete(String id) {
    return repository.deleteBudget(id);
  }

  Future<List<BudgetEntity>> getAll({BudgetQueryOptions? options}) {
    return repository.getAllBudgets(options: options);
  }

  Future<BudgetEntity?> getById(String id) {
    return repository.getBudgetById(id);
  }

  Future<BudgetEntity?> getActive() {
    return repository.getActiveBudget();
  }

  Future<BudgetEntity> archive(String id, {required bool archived}) {
    return repository.setBudgetArchived(id, archived: archived);
  }

  Future<BudgetEntity> duplicate(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.duplicateBudget(
      id,
      newName: newName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> setActive(String id) {
    return repository.setActiveBudgetId(id);
  }

  Future<String?> activeBudgetId() {
    return repository.getActiveBudgetId();
  }

  /// Validates budget input. Returns an error message or null if valid.
  String? validate(
    String name,
    double amount,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (name.trim().isEmpty) {
      return 'Budget name cannot be empty.';
    }
    if (amount <= 0) {
      return 'Budget amount must be greater than zero.';
    }
    if (!endDate.isAfter(startDate)) {
      return 'End date must be after the start date.';
    }
    return null;
  }
}
