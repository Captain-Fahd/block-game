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
