# 001. aapt2 on NixOS

Date: 2026-11-10
Status: Accepted

## Context
Gradle downloads a dynamically linked `aapt2` from Maven, which fails on NixOS because there is no FHS dynamic loader. Two fixes: override aapt2 with the SDK's Nix-patched binary, or enable `programs.nix-ld` system-wide.

## Decision
Override via `GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/<ver>/aapt2"`, set in the `flake.nix` shell hook.

## Consequences
- Works per project with no system configuration change; anyone with Nix gets the same result.
- The build-tools version in the override must exist in the flake; bump both together.
- If another downloaded native tool breaks later, `programs.nix-ld.enable = true` in the NixOS config is the fallback.

## Addendum (2026-11-11): read-only SDK plugin projects
`flutter test integration_test` failed on NixOS: Gradle 9 refuses to configure the `:integration_test` plugin project because its directory is in the read-only Nix store ("Configuring project ':integration_test' without an existing directory is not allowed ... can't be written to"). `apps/block_puzzle/android/settings.gradle.kts` now points any non-writable included project at a writable copy under `build/nix-sdk-plugins/`. It does nothing on a normal writable SDK, so CI (subosito/flutter-action) is unaffected. New apps need the same snippet.
