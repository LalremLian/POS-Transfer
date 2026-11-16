import 'package:equatable/equatable.dart';

class UploadResult extends Equatable {
  const UploadResult({
    required this.id,
    required this.name,
    required this.originalName,
    required this.size,
    required this.type,
    required this.uploadedAt,
    required this.url,
  });

  final int id;
  final String name;
  final String originalName;
  final int size;
  final String type;
  final DateTime uploadedAt;
  final String url;

  @override
  List<Object?> get props => [id, name, size, url];
}
