import 'package:flutter_test/flutter_test.dart';
import '../../tool/check_environment.dart';

void main() {
  test('rejects newer SDKs and a Dart executable from a different SDK', () {
    expect(
      versionProblems(
        flutter: '3.41.5',
        dart: '3.11.3',
        runningDart: '3.11.3',
        expectedFlutter: '3.41.5',
        expectedDart: '3.11.3',
      ),
      isEmpty,
    );
    expect(
      versionProblems(
        flutter: '3.44.0',
        dart: '3.12.0',
        runningDart: '3.12.0',
        expectedFlutter: '3.41.5',
        expectedDart: '3.11.3',
      ),
      hasLength(3),
    );
    expect(
      versionProblems(
        flutter: '3.41.5',
        dart: '3.11.3',
        runningDart: '3.10.0',
        expectedFlutter: '3.41.5',
        expectedDart: '3.11.3',
      ),
      hasLength(1),
    );
  });
}
