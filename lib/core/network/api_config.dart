abstract final class ApiConfig {
  static const baseUrl =
      'https://distance-laura-fits-concerned.trycloudflare.com';
  static const platformVersion = 'v1';

  /// Keeps full external image URLs (for example Google Cloud Storage) intact.
  /// Relative image paths still resolve through the configured backend host.
  static String? resolveImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final rawPath = imagePath.trim();
    if (rawPath.startsWith('data:image/')) return rawPath;
    final source = Uri.tryParse(rawPath);
    if (source?.hasScheme == true) return rawPath;
    final path = rawPath;
    return Uri.parse(baseUrl)
        .resolve(path.startsWith('/') ? path : '/$path')
        .toString();
  }
}
