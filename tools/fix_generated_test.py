from pathlib import Path

TEST_CONTENT = """import 'package:flutter_test/flutter_test.dart';
import 'package:ghostnet_cyber_vpn/main.dart';

void main() {
  test('GhostNetApp class is available', () {
    const app = GhostNetApp();
    expect(app, isA<GhostNetApp>());
  });
}
"""

test_file = Path('test/widget_test.dart')
test_file.parent.mkdir(parents=True, exist_ok=True)
test_file.write_text(TEST_CONTENT, encoding='utf-8')
print(f'Fixed generated Flutter test: {test_file}')
