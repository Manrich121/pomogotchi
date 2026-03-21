class AnimalSpec {
  const AnimalSpec({
    required this.id,
    required this.displayName,
    required this.artAssetPath,
    required this.platformAssetPath,
  });

  factory AnimalSpec.fromAnimalAsset(String assetPath) {
    final fileName = assetPath.split('/').last;
    final id = fileName.split('.').first;

    return AnimalSpec(
      id: id,
      displayName: _titleCase(id),
      artAssetPath: assetPath,
      platformAssetPath: 'assets/platforms/$id-platform.png',
    );
  }

  final String id;
  final String displayName;
  final String artAssetPath;
  final String platformAssetPath;

  static String _titleCase(String rawValue) {
    final words = rawValue.split(RegExp(r'[_-]+'));
    return words
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
