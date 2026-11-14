import 'package:equatable/equatable.dart';

class AuthToken extends Equatable {
  const AuthToken({
    required this.token,
    required this.tokenType,
    required this.username,
    required this.userId,
    required this.expiresAt,
  });

  final String token;
  final String tokenType;
  final String username;
  final int userId;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired && token.isNotEmpty;

  @override
  List<Object?> get props => [token, tokenType, username, userId, expiresAt];
}

class AuthState extends Equatable {
  const AuthState({
    this.token,
    this.isLoading = false,
    this.error,
  });

  final AuthToken? token;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => token != null && token!.isValid;

  AuthState copyWith({
    AuthToken? token,
    bool? isLoading,
    String? error,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [token, isLoading, error];
}
