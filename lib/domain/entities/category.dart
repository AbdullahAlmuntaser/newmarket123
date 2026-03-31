import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final String? code;

  const Category({required this.id, required this.name, this.code});

  @override
  List<Object?> get props => [id, name, code];
}
