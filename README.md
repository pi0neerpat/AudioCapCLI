# AudioCapCLI

A command-line interface for capturing audio from applications on macOS, forked from [insidegui/AudioCap](https://github.com/insidegui/AudioCap).

## Overview

AudioCapCLI converts the original AudioCap GUI application into a command-line tool that can be integrated with other applications. This CLI version makes it easy to programmatically:

- List available audio sources
- Capture audio from specific applications
- Stream the captured audio to stdout for further processing

## Usage

```
AudioCapCLI - Capture audio from applications

Usage:
  AudioCapCLI --list-sources                List all available audio sources
  AudioCapCLI --source <name>               Record audio from specified source

Examples:
  AudioCapCLI --list-sources
  AudioCapCLI --source Chrome
  AudioCapCLI --source "com.google.Chrome"
```

### Listing Available Sources

```bash
AudioCapCLI --list-sources
```

This will output a list of available audio sources in the format:
```
AppName|48000 Hz, 2 ch|Base64EncodedIcon
```

### Capturing Audio

```bash
AudioCapCLI --source "Chrome"
```

This will capture audio from the specified source and stream it to stdout as raw PCM audio data. The audio capture continues until you interrupt the process (e.g., with Ctrl+C).

You can specify the source by:
- Application name (e.g., "Chrome")
- Partial application name (e.g., "Fire" would match "Firefox")
- Bundle ID (e.g., "com.google.Chrome")

## Integration Example

Below is an example of how to integrate AudioCapCLI with Node.js from a real implementation:

```javascript
// List available audio sources
const listSourcesProcess = child_process.spawn(AUDIO_CAPTURE_EXE_PATH, [
  "--list-sources",
]);

let sourcesData = "";
listSourcesProcess.stdout.on("data", (data) => {
  sourcesData += data.toString();
});

// Parse sources output
const sources = sourcesData
  .split("\n")
  .filter((line) => line.trim())
  .map((line) => {
    const [fullName, formatStr, icon] = line.split("|");
    const formatMatch = formatStr
      ? formatStr.match(/(\d+)\s*Hz,\s*(\d+)\s*ch/)
      : null;
    return {
      id: fullName.trim(),
      name: fullName.trim(),
      sampleRate: formatMatch ? parseInt(formatMatch[1]) : 44100,
      channels: formatMatch ? parseInt(formatMatch[2]) : 2,
      icon: icon ? icon.trim() : null,
    };
  });

// Start audio capture
const systemAudioCapturer = child_process.spawn(
  AUDIO_CAPTURE_EXE_PATH,
  ["--source", sourceId]
);

// Process the raw audio data
systemAudioCapturer.stdout.on("data", (chunk) => {
  // Process the PCM audio data
  // ...
});
```

## Original AudioCap Project

This CLI tool is based on [AudioCap by Guilherme Rambo](https://github.com/insidegui/AudioCap), which provides a GUI for the same functionality. The original project documentation below gives additional context about the CoreAudio APIs used.

---

## How It Works

With macOS 14.4, Apple introduced new API in CoreAudio that allows any app to capture audio from other apps or the entire system, as long as the user has given the app permission to do so.

### Permission

Recording audio from other apps requires a permission prompt. The message for this prompt is defined by adding the `NSAudioCaptureUsageDescription` key to the app's Info.plist.

### Process Tap Setup

The CLI tool uses the following process:
1. Retrieves a list of available audio processes
2. Filters out system processes that typically don't produce useful audio
3. For a selected process, creates an audio tap and streams the audio data to stdout
4. The raw PCM audio data can then be processed by downstream applications

## Requirements

- macOS 14.4 or later
- Audio recording permission

## Credits

- Original AudioCap by [Guilherme Rambo](https://github.com/insidegui)
- CLI adaptation by [PI0neerpat](https://github.com/pi0neerpat)
