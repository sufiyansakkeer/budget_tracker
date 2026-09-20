import 'package:equatable/equatable.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

class CategoryLoad extends CategoryEvent {
  const CategoryLoad();
}

/// Creates ([id] null) or updates a category.
class CategorySave extends CategoryEvent {
  final String? id;
  final String name;
  final String icon;
  final String colorHex;

  const CategorySave({
    this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
  });

  @override
  List<Object?> get props => [id, name, icon, colorHex];
}

class CategorySetArchived extends CategoryEvent {
  final String id;
  final bool archived;

  const CategorySetArchived(this.id, {required this.archived});

  @override
  List<Object?> get props => [id, archived];
}

class CategoryDelete extends CategoryEvent {
  final String id;

  const CategoryDelete(this.id);

  @override
  List<Object?> get props => [id];
}

class CategoryClearMessage extends CategoryEvent {
  const CategoryClearMessage();
}
