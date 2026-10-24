import 'package:integration_test/integration_test_driver.dart';

/// Writes each frame-time summary of `tab_bar_perf_test.dart` to
/// `build/tab_bar_perf.json`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) =>
      writeResponseData(data, testOutputFilename: 'tab_bar_perf'),
);
