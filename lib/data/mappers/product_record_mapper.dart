import '../../domain/entities/models.dart';
import 'product_image_paths.dart';

Product productFromRecord(Map record, {List<String>? imageUrls}) {
  final images = imageUrls ?? ProductImagePaths.fromRecord(record);
  return Product(
    name: record['productName']?.toString() ?? 'Unnamed product',
    variantId: (record['variantId'] ?? record['variant_id'] ?? record['id'])
        ?.toString(),
    mainImage: images.firstOrNull,
    imageUrls: images,
    description: record['productDetails']?.toString(),
    category: record['categoryName']?.toString(),
    brand: record['brandName']?.toString(),
    flavour: record['flavour']?.toString(),
    breedSize: record['breedSize']?.toString(),
    petType: record['petType']?.toString(),
    lifeStage: record['lifeStage']?.toString(),
    unitSize: record['unitSize']?.toString(),
    unitType: record['unitType']?.toString(),
    price: record['finalPrice'],
    mrp: record['mrpPrice'] ?? record['mrp'],
    variants: [
      if (record['variants'] is List)
        for (final v in (record['variants'] as List).whereType<Map>())
          ProductVariant(
            variantId:
                (v['variantId'] ?? v['varientId'] ?? v['id'])?.toString(),
            unitSize: v['unitSize']?.toString(),
            unitType: v['unitType']?.toString(),
            price: v['finalPrice'] ?? v['price'],
            mrp: v['mrpPrice'] ?? v['mrp'],
            images: ProductImagePaths.fromRecord(v),
            isDefault: v['isDefault'] == true ||
                v['isDefault']?.toString().toLowerCase() == 'true',
          ),
    ],
  );
}
