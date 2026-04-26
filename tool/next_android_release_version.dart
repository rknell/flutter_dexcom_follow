import 'dart:convert';
import 'dart:io';

import 'release_version.dart';

Future<void> main(List<String> arguments) async {
  final pubspecPath = arguments.isEmpty ? 'pubspec.yaml' : arguments.first;
  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    stderr.writeln('Could not find pubspec at $pubspecPath');
    exitCode = 64;
    return;
  }

  final tagsInput = await stdin.transform(utf8.decoder).join();
  final tags = tagsInput
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  final version = nextAndroidReleaseVersion(
    tags: tags,
    pubspecYaml: pubspecFile.readAsStringSync(),
  );

  final output = [
    'version=${version.fullVersion}',
    'build_name=${version.buildName}',
    'build_number=${version.buildNumber}',
    'tag=${version.tagName}',
  ];

  stdout.writeln(output.join('\n'));

  final githubOutputPath = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutputPath == null || githubOutputPath.isEmpty) {
    return;
  }

  File(
    githubOutputPath,
  ).writeAsStringSync('${output.join('\n')}\n', mode: FileMode.append);
}
