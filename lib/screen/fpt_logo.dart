import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official FPT Education logo (wide wordmark, bundled SVG asset).
class FptLogo extends StatelessWidget {
  const FptLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/fpt_education_logo.svg',
      key: const Key('fptLogo'),
      height: height,
      semanticsLabel: 'FPT Education',
    );
  }
}
