import 'dart:math' as math;
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
    this.bottomPadding,
    this.itemHeight,
    this.maxWideCardWidth,
  });

  /// Extra space below the last row (e.g. room for a floating button).
  final double? bottomPadding;
  final double? itemHeight;
  final double? maxWideCardWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isTablet = width >= 600;
          final columns = width >= 1100 ? 4 : (isTablet ? 3 : 2);
          final padding = isTablet ? 24.0 : 16.0;
          const spacing = 12.0;
          final wideCardWidth = maxWideCardWidth;
          final gridWidth = isTablet && wideCardWidth != null
              ? math.min(
                  1200.0,
                  columns * wideCardWidth +
                      (columns - 1) * spacing +
                      2 * padding)
              : 1200.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: gridWidth),
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  bottomPadding ?? padding,
                ),
                itemCount: itemCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  mainAxisExtent: itemHeight ?? (isTablet ? 320 : 330),
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
    this.imageAction,
  });

  final Product product;
  final Uint8List? imageBytes;
  final VoidCallback? onTap;
  final Widget? actions;
  final Widget? imageAction;

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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: FittedBox(
                            fit: BoxFit.scaleDown, child: _image(context)),
                      ),
                      if (imageAction != null)
                        PositionedDirectional(
                          end: 4,
                          bottom: 4,
                          child: imageAction!,
                        ),
                    ],
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

  Widget _image(BuildContext context) {
    const size = 175.0;
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
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
        image: ResizeImage.resizeIfNeeded(decodeSize, null, provider),
        width: size,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Product image',
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
