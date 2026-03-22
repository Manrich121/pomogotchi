import 'package:flutter/services.dart';
import 'package:pomogotchi/models/animal_spec.dart';

Future<List<AnimalSpec>> discoverAnimalSpecs(AssetBundle assetBundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(assetBundle);
  final animalAssets =
      manifest
          .listAssets()
          .where(
            (assetPath) =>
                assetPath.startsWith('assets/animals/') &&
                assetPath.toLowerCase().endsWith('.png'),
          )
          .toList()
        ..sort();

  return animalAssets.map(AnimalSpec.fromAnimalAsset).toList(growable: false);
}
