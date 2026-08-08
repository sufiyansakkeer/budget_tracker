/// Compatibility placeholder.
///
/// The budget feature exposes multi-budget operations through
/// [ManageBudgetUseCase] (see manage_budget_usecase.dart). The onboarding
/// feature owns its own `CreateBudgetUseCase` for first-launch setup, so we do
/// not redeclare a conflicting class here.
library;

// Intentionally empty to avoid a name collision with Onboarding's
// CreateBudgetUseCase. Budget creation at runtime uses ManageBudgetUseCase.
