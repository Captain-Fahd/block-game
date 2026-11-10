{
  description = "F2P games dev shell: Flutter + Android SDK (API 35/36)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      # Versions Flutter's Gradle plugin asks for (Flutter 3.47: compileSdk 36,
      # NDK 28.2.13676358, AGP 9.1). If a build error names a different NDK or
      # build-tools version, add it here instead of letting Gradle download it.
      buildToolsVersion = "36.0.0";
      ndkVersion = "28.2.13676358";
      cmakeVersion = "3.22.1";

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        # 34: firebase_* plugins compile against it.
        platformVersions = [ "34" "35" "36" ];
        buildToolsVersions = [ "35.0.0" buildToolsVersion ];
        includeNDK = true;
        ndkVersions = [ ndkVersion ];
        cmakeVersions = [ cmakeVersion ];
        includeEmulator = true;
        includeSystemImages = true;
        systemImageTypes = [ "google_apis_playstore" ];
        abiVersions = [ "x86_64" ];
        includeSources = false;
      };
      androidSdk = androidComposition.androidsdk;
      jdk = pkgs.jdk17;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.flutter
          jdk
          androidSdk
        ];

        ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
        ANDROID_NDK_HOME = "${androidSdk}/libexec/android-sdk/ndk/${ndkVersion}";
        JAVA_HOME = "${jdk.home}";

        shellHook = ''
          # Prefer the SDK's adb over any system-wide android-tools adb.
          export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
          # Gradle's downloaded aapt2 is dynamically linked and won't run on NixOS.
          # Point AGP at the SDK's patched aapt2 instead (see docs/decisions/001).
          export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/${buildToolsVersion}/aapt2"
          flutter config --android-sdk "$ANDROID_HOME" >/dev/null 2>&1 || true
          flutter config --jdk-dir "$JAVA_HOME" >/dev/null 2>&1 || true
        '';
      };
    };
}
