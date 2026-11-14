import '../../domain/entities/auth_token.dart';

class TokenResponseModel {
  const TokenResponseModel({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.username,
    required this.expiresIn,
  });

  final String token;
  final String tokenType;
  final int userId;
  final String username;
  final int expiresIn; // seconds

  factory TokenResponseModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return TokenResponseModel(
      token: json['token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      userId: (user['id'] as num?)?.toInt() ?? 0,
      username: user['username'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 86400,
    );
  }

  AuthToken toDomain() {
    return AuthToken(
      token: token,
      tokenType: tokenType,
      username: username,
      userId: userId,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}
