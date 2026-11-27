import 'dart:convert';

abstract final class ProductImagePaths {
  static bool isImageField(String field) {
    final key = field.split('.').last.toLowerCase().replaceAll('_', '');
    if (const {'fileurl', 'media', 'mediaurl', 'secureurl'}.contains(key)) {
      return false;
    }
    return _imageFields.any((name) => name.toLowerCase() == key);
  }

  static const _imageFields = [
    'mainImage',
    'mainImageUrl',
    'mainImagePath',
    'imageUrl',
    'imageUrls',
    'image',
    'primaryImage',
    'primaryImageUrl',
    'defaultImage',
    'defaultImageUrl',
    'productImage',
    'productImageUrl',
    'productImages',
    'subImage',
    'subImages',
    'additionalImages',
    'otherImages',
    'secondaryImages',
    'imagePath',
    'fileUrl',
    'mediaUrl',
    'secureUrl',
    'thumbnail',
    'thumbnailUrl',
    'images',
    'imageList',
    'productImageList',
    'subImageList',
    'gallery',
    'media',
  ];

  static List<String> fromRecord(Map record) => {
        for (final key in _imageFields) ...fromValue(record[key]),
      }.toList(growable: false);

  static List<String> fromValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final raw = value.trim();
      if ((raw.startsWith('{') && raw.endsWith('}')) ||
          (raw.startsWith('[') && raw.endsWith(']'))) {
        try {
          return fromValue(jsonDecode(raw));
        } on FormatException {
          // Treat malformed JSON text as a direct backend path below.
        }
      }
      return [raw];
    }
    if (value is List) {
      return value.expand(fromValue).toList(growable: false);
    }
    if (value is Map) {
      final paths = <String>[];
      for (final key in const [
        'url',
        'imageUrl',
        'path',
        'filePath',
        'location',
        'mediaUrl',
        'fileUrl',
        'imagePath',
        'downloadUrl',
        'publicUrl',
      ]) {
        paths.addAll(fromValue(value[key]));
      }
      for (final nestedKey in const [
        'image',
        'file',
        'media',
        'asset',
        'images',
        'subImages',
        'additionalImages',
      ]) {
        paths.addAll(fromValue(value[nestedKey]));
      }
      return paths;
    }
    return const [];
  }
}
