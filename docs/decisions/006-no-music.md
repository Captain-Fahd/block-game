# 006. No music in the block puzzle

Date: 2026-11-11
Status: accepted (Omar's decision)

## Context
The Phase 2 spec listed a Music toggle in Settings, and `game_core`'s audio service supports one looping music track. The game never had a track, so the toggle did nothing. Omar: "Don't have a music option or any music."

## Decision
The block puzzle has no music and no Music setting. Sound effects and vibration stay. The Music line is removed from SPEC.md's Settings list (and the copy in PLAN.md).

## Consequences
- Settings shows sound effects, vibration, colour-blind patterns, privacy, how to play, credits and version.
- `game_core` keeps its optional music support (`Settings.music`, `FlameAudioService.musicFile`), since a later game may want it. The block puzzle passes no music file, so no music can ever play, and the stored setting is simply unused.
- No music asset means nothing to license or credit.
