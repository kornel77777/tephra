# Lecture Recorder

A macOS app for recording lectures and transcribing them fully offline with
[WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) (Core ML, runs on
the Neural Engine / GPU). No cloud APIs, no accounts, no per-use cost. The only
network access is the one-time model download from Hugging Face.

## Requirements

- Apple Silicon Mac, macOS 14+
- Xcode 15+ **or** a working Command Line Tools install (see note below)

> **Note on Command Line Tools:** Swift Package Manager needs a working
> `PackageDescription` library to even read `Package.swift`. If `swift build`
> or `swift package resolve` fails with a linker error mentioning
> `PackageDescription.Package.__allocating_init`, your Command Line Tools
> install is corrupted/partial (this can happen after an interrupted or
> stacked update). Fix it with either:
> - Install full Xcode from the App Store (recommended — this project also
>   builds fine as a normal Xcode project once Xcode is present), or
> - `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`

## Project layout

```
Sources/
  LectureRecorderCore/     Shared logic: transcription, audio, persistence, export
  lecture-recorder-cli/    Phase 1 CLI — transcribe a file from the terminal
  LectureRecorderApp/      Phase 2/3 SwiftUI app — record, queue, library, settings
Resources/
  Info.plist                     App bundle metadata (mic usage description, etc.)
  LectureRecorderApp.entitlements
Scripts/
  build_app.sh             Builds + packages the SwiftPM executable into a .app
```

## Building

### CLI (Phase 1) — verify the transcription pipeline first

```bash
swift run lecture-recorder-cli --audio /path/to/lecture.m4a --model openai_whisper-large-v3 --prompt "Rawls, Hobbes, Leviathan"
```

Available `--model` values:
- `openai_whisper-large-v3` (default — full precision, most accurate, slowest)
- `large-v3-v20240930_turbo` (fast)
- `large-v3-v20240930_626MB` (compressed turbo, Argmax's recommended fast option)

The first run for any model downloads it to
`~/Library/Application Support/LectureRecorder/models` and then spends a few
minutes "specializing" it for the Neural Engine — this also happens again
after major OS updates. Subsequent runs are fast to load.

### App (Phase 2/3)

With Xcode installed, open the folder in Xcode (File > Open) and run the
`LectureRecorderApp` scheme directly — no `.xcodeproj` is checked in, Xcode
can run a Swift package's executable target as-is.

Without Xcode (Command Line Tools only), build and package it manually:

```bash
Scripts/build_app.sh release
open .build/LectureRecorderApp.app
```

The script builds the executable, assembles a minimal `.app` bundle with the
Info.plist from `Resources/`, and ad-hoc signs it (`codesign -s -`). Ad-hoc
signing plus the `NSMicrophoneUsageDescription` key in Info.plist is what
makes macOS show the microphone permission prompt at all — without both, the
app is silently denied access.

## First run

1. Launch the app, go to Settings, pick a transcription model, and press
   Download. This is the only step that needs internet access.
2. Add at least one subject (course code + display name + optional glossary
   of proper nouns/jargon — this is what most improves transcription accuracy
   for lecture-specific terms).
3. Point "Obsidian Vault" at your vault folder. Notes go to
   `Lectures/transcripts/`, audio to `Lectures/audio/`.
4. Record, or drag a `.m4a`/`.mp3`/`.wav`/`.flac` file onto the Record tab to
   import and transcribe it instead.

## Design notes / known limitations

- **Crash safety**: recording is written as linear-PCM CAF while it's in
  progress (a `.m4a`'s moov atom is only finalized on clean close, so a crash
  mid-recording would otherwise corrupt the whole file). On Stop, the CAF is
  transcoded to AAC `.m4a` and the CAF is deleted. If the app is killed before
  Stop is pressed, the `.caf` file survives in
  `~/Library/Application Support/LectureRecorder/Recordings/` and can be
  converted manually (`afconvert -f m4af -d aac input.caf output.m4a`) even
  though there's no in-app recovery flow yet.
- **Lid-closed behavior**: `ProcessInfo.beginActivity(.idleSystemSleepDisabled)`
  prevents idle sleep while recording, but closing the lid on most Apple
  Silicon MacBooks still suspends the machine unless it's connected to power
  and an external display (clamshell mode), or an app has taken a stronger
  assertion than this app requests. Keep the lid open, or plug in power and
  use clamshell mode, for long recordings.
- **Model choice**: `openai_whisper-large-v3` is the default because accuracy
  is prioritized over speed per the project's goals. Switch to one of the
  turbo variants in Settings if a lecture needs to be processed faster.
- **Incremental audio loading**: used automatically for very large imported
  files to bound memory; in that mode WhisperKit can't use clip timestamps,
  which this app doesn't rely on anyway.
- **Input device switching**: macOS has no `AVAudioSession`, so selecting a
  non-default microphone goes through Core Audio's
  `kAudioOutputUnitProperty_CurrentDevice` directly — this is the part most
  worth re-testing against real external/Continuity microphones.
- **Post-processing** is intentionally simple rule-based cleanup (duplicate
  consecutive segments, a fixed list of known silence hallucinations, stray
  `<|...|>` tokens) rather than anything model-based.

## Status

- Phase 1 (CLI transcription proof of concept): implemented.
- Phase 2 (recording, queue, Obsidian export): implemented, not yet run
  end-to-end against real hardware/microphones.
- Phase 3 (bookmarks, library, settings, packaging): implemented at the code
  level (bookmarks, library list with retry, subject/model/vault settings,
  `.app` packaging script); needs a real-machine pass to confirm mic
  permissions, device switching, and long-recording behavior end-to-end.

Benchmarks (90-minute lecture, full `large-v3`, wall-clock vs. real time) are
not filled in yet — measure on your machine and update this section.

## Out of scope (for now)

Real-time captioning, speaker diarization, local LLM summarization, and an
iOS companion are intentionally not part of this app.
