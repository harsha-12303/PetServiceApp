import 'package:flutter/material.dart';

/// The PetWork logo (dog and cat on navy), with rounded corners.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 52});

  final double size;

  static const asset = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          semanticLabel: 'PetWork logo',
        ),
      );
}
