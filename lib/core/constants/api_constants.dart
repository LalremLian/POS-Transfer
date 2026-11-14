class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://108.136.142.112:90';

  // Auth
  /// POST
  static const String register = '/register';

  /// POST
  static const String token = '/token';

  // ── Files ─────────────────────────────────────────────────────────────────
  /// GET
  static const String getFiles = '/get';

  /// GET
  static const String downloadFile = '/get';

  /// POST
  static const String uploadFile = '/upload';

  /// DELETE ?file=NAME
  static const String deleteFile = '/delete';

  // Query param keys
  static const String fileParam = 'file';
}
