import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader_example/example_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the refraction shader loads from the package on Impeller', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    for (var i = 0; i < 50 && !LiquidGlassShader.isReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(LiquidGlassShader.isReady, isTrue);
    expect(
      GlassScope.qualityOf(tester.element(find.byType(LiquidTabBar))),
      GlassQuality.refraction,
    );
  });
}
