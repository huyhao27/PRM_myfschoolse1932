import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfschoolse1932/screen/fpt_logo.dart';

void main() {
  testWidgets('FptLogo renders the bundled SVG asset at the given height',
      (t) async {
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: FptLogo(height: 40))));
    final svg = t.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.height, 40);
    expect(svg.semanticsLabel, 'FPT Education');
    expect((svg.bytesLoader as SvgAssetLoader).assetName,
        'assets/images/fpt_education_logo.svg');
    expect(t.getSize(find.byType(FptLogo)).height, 40);
  });
}
