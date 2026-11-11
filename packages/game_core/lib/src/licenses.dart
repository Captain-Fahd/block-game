import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds licences for assets bundled by game_core (not covered by pub
/// package licences) to Flutter's licence page. Call once at startup.
void registerGameCoreLicenses() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString(
      'packages/game_core/assets/fonts/Nunito-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Nunito font'], ofl);
  });
}
