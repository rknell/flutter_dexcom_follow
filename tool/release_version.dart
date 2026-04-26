class AndroidReleaseVersion implements Comparable<AndroidReleaseVersion> {
  const AndroidReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  static final RegExp _versionPattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
  );

  final int major;
  final int minor;
  final int patch;
  final int buildNumber;

  static AndroidReleaseVersion? parse(String rawVersion) {
    final match = _versionPattern.firstMatch(rawVersion.trim());
    if (match == null) {
      return null;
    }

    final majorText = match.group(1);
    final minorText = match.group(2);
    final patchText = match.group(3);
    if (majorText == null || minorText == null || patchText == null) {
      return null;
    }

    final major = int.tryParse(majorText);
    final minor = int.tryParse(minorText);
    final patch = int.tryParse(patchText);
    if (major == null || minor == null || patch == null) {
      return null;
    }

    final buildText = match.group(4);
    final buildNumber = buildText == null ? 0 : int.tryParse(buildText);
    if (buildNumber == null) {
      return null;
    }

    return AndroidReleaseVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNumber,
    );
  }

  AndroidReleaseVersion nextPatchRelease() {
    return AndroidReleaseVersion(
      major: major,
      minor: minor,
      patch: patch + 1,
      buildNumber: buildNumber + 1,
    );
  }

  String get buildName => '$major.$minor.$patch';

  String get fullVersion => '$buildName+$buildNumber';

  String get tagName => 'v$fullVersion';

  @override
  int compareTo(AndroidReleaseVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }

    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }

    final patchComparison = patch.compareTo(other.patch);
    if (patchComparison != 0) {
      return patchComparison;
    }

    return buildNumber.compareTo(other.buildNumber);
  }
}

AndroidReleaseVersion? highestTaggedVersion(Iterable<String> rawTags) {
  AndroidReleaseVersion? highest;

  for (final rawTag in rawTags) {
    final parsed = AndroidReleaseVersion.parse(rawTag);
    if (parsed == null) {
      continue;
    }

    final currentHighest = highest;
    if (currentHighest == null || parsed.compareTo(currentHighest) > 0) {
      highest = parsed;
    }
  }

  return highest;
}

AndroidReleaseVersion pubspecVersion(String pubspecYaml) {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecYaml);
  final versionText = match?.group(1);
  if (versionText == null) {
    return const AndroidReleaseVersion(
      major: 0,
      minor: 0,
      patch: 0,
      buildNumber: 0,
    );
  }

  return AndroidReleaseVersion.parse(versionText) ??
      const AndroidReleaseVersion(major: 0, minor: 0, patch: 0, buildNumber: 0);
}

AndroidReleaseVersion nextAndroidReleaseVersion({
  required Iterable<String> tags,
  required String pubspecYaml,
}) {
  final taggedVersion = highestTaggedVersion(tags);
  final baseVersion = taggedVersion ?? pubspecVersion(pubspecYaml);
  return baseVersion.nextPatchRelease();
}
