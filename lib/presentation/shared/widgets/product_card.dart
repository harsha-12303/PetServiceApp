import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isTablet = width >= 600;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: GridView.builder(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                itemCount: itemCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: width >= 1100 ? 4 : (isTablet ? 3 : 2),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: isTablet ? 320 : 330,
                ),
                itemBuilder: itemBuilder,
              ),
            ),
          );
        },
      );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.imageBytes,
    this.onTap,
    this.actions,
  });

  final Product product;
  final Uint8List? imageBytes;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: AppColors.card,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SizedBox(
                  height: 180,
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: _image()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 35,
                child: Text(
                  product.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    product.unitLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (product.price != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '\u20B9${product.price}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ]),
              if (actions != null) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _image() {
    const size = 175.0;
    final placeholder = Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.imageBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.pets_outlined,
          semanticLabel: 'Product image unavailable'),
    );
    final bytes = imageBytes;
    final url = ApiConfig.resolveImageUrl(product.mainImage);
    final ImageProvider<Object> provider;
    if (bytes != null) {
      provider = MemoryImage(bytes);
    } else if (url != null) {
      provider = NetworkImage(url);
    } else {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Product image',
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
