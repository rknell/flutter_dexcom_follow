import 'package:flutter_test/flutter_test.dart';

import '../tool/release_version.dart';

void main() {
  test('🚀 FEATURE: next Android release uses highest numeric tag', () {
    final next = nextAndroidReleaseVersion(
      tags: const [
        'v1.0.4+7',
        'v1.2.0+4',
        'not-a-release',
        '0.9.9+99',
        'v1.2.0+5',
      ],
      pubspecYaml: 'version: 9.9.9+99',
    );

    expect(next.buildName, '1.2.1');
    expect(next.buildNumber, 6);
    expect(next.fullVersion, '1.2.1+6');
    expect(next.tagName, 'v1.2.1');
  });

  test(
    '🎯 EDGE_CASE: build number keeps increasing after clean semver tags',
    () {
      final next = nextAndroidReleaseVersion(
        tags: const ['v1.0.1+2', 'v1.0.2'],
        pubspecYaml: 'version: 1.0.0+1',
      );

      expect(next.buildName, '1.0.3');
      expect(next.buildNumber, 4);
      expect(next.fullVersion, '1.0.3+4');
      expect(next.tagName, 'v1.0.3');
    },
  );

  test(
    '🎯 EDGE_CASE: pubspec version seeds first release when no tags exist',
    () {
      final next = nextAndroidReleaseVersion(
        tags: const [],
        pubspecYaml: 'name: app\nversion: 1.0.0+1\n',
      );

      expect(next.fullVersion, '1.0.1+2');
      expect(next.tagName, 'v1.0.1');
    },
  );
}
