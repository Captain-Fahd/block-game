import 'package:meta/meta.dart';

/// A cross-promo card for another of Omar's games.
@immutable
class HouseAd {
  const HouseAd({
    required this.packageId,
    required this.title,
    required this.tagline,
  });

  final String packageId;
  final String title;
  final String tagline;

  Uri get storeUri =>
      Uri.parse('https://play.google.com/store/apps/details?id=$packageId');
}

/// Static list of house ads, filtered to exclude the current app.
/// Empty for game 1; filled in once more games are live.
class HouseAds {
  const HouseAds({required this.currentPackageId, this.all = kHouseAds});

  final String currentPackageId;
  final List<HouseAd> all;

  List<HouseAd> get available =>
      all.where((a) => a.packageId != currentPackageId).toList();

  HouseAd? pick(int index) {
    final list = available;
    return list.isEmpty ? null : list[index % list.length];
  }
}

const List<HouseAd> kHouseAds = [];
