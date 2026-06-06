// app/test/core/settings/app_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/settings/app_settings.dart';

void main() {
  test('default base url points at localhost backend', () {
    expect(const AppSettings().backendBaseUrl, 'http://localhost:8000');
  });

  test('base url is overridable', () {
    const s = AppSettings(backendBaseUrl: 'http://10.0.0.5:8000');
    expect(s.backendBaseUrl, 'http://10.0.0.5:8000');
  });
}
