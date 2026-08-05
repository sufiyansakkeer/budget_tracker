/// Sort options for the expense history screen.
enum ExpenseSortOption {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
  category,
  alphabetical;

  /// Human-readable label.
  String get label {
    switch (this) {
      case ExpenseSortOption.newestFirst:
        return 'Newest First';
      case ExpenseSortOption.oldestFirst:
        return 'Oldest First';
      case ExpenseSortOption.highestAmount:
        return 'Highest Amount';
      case ExpenseSortOption.lowestAmount:
        return 'Lowest Amount';
      case ExpenseSortOption.category:
        return 'Category';
      case ExpenseSortOption.alphabetical:
        return 'Alphabetical';
    }
  }

  /// Icon name (Material) for the option.
  String get iconName {
    switch (this) {
      case ExpenseSortOption.newestFirst:
        return 'arrow_downward';
      case ExpenseSortOption.oldestFirst:
        return 'arrow_upward';
      case ExpenseSortOption.highestAmount:
        return 'trending_down';
      case ExpenseSortOption.lowestAmount:
        return 'trending_up';
      case ExpenseSortOption.category:
        return 'category';
      case ExpenseSortOption.alphabetical:
        return 'sort_by_alpha';
    }
  }
}
