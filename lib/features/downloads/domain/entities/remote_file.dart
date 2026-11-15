import 'package:equatable/equatable.dart';

class RemoteFile extends Equatable {
  const RemoteFile({
    required this.id,
    required this.name,
    required this.originalName,
    required this.size,
    required this.type,
    required this.uploadedAt,
    required this.url,
  });

  final int id;
  final String name;        // server-side name (has hex suffix) — used in download URL
  final String originalName;
  final int size;           // bytes
  final String type;        // mime type
  final DateTime uploadedAt;
  final String url;

  factory RemoteFile.fromJson(Map<String, dynamic> json) => RemoteFile(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        originalName: json['original_name'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? '',
        uploadedAt: DateTime.tryParse(
              json['uploaded_at'] as String? ?? '',
            ) ??
            DateTime.now(),
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'original_name': originalName,
        'size': size,
        'type': type,
        'uploaded_at': uploadedAt.toIso8601String(),
        'url': url,
      };

  @override
  List<Object?> get props => [id, name, size, url];
}
