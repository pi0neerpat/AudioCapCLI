# AudioCapCLI v1.0.0 Release Notes

### Features

- **Command Line Interface**: Capture audio from any application via simple terminal commands
- **Application Listing**: Identify available audio sources with detailed information
- **Flexible Source Selection**: Target applications by name or bundle ID
- **Stream Output**: Direct PCM audio output to stdout for integration with other tools
- **Format Information**: View audio format details (sample rate, channels) for each source
- **Process Filtering**: Intelligent filtering of system processes that typically don't produce useful audio
- **Integration Ready**: Designed to be easily incorporated into other applications

### Technical Details

- Built on Apple's CoreAudio process tap API introduced in macOS 14.4
- Raw PCM audio streaming via stdout

### Requirements

- macOS 14.4 or later
- Audio recording permission

### Usage Examples

**List all available audio sources:**
```
AudioCapCLI --list-sources
```

**Capture audio from a specific application:**
```
AudioCapCLI --source "Chrome"
```

**Capture audio using a bundle identifier:**
```
AudioCapCLI --source "com.google.Chrome"
```

### Acknowledgments

AudioCapCLI is a fork of [AudioCap by Guilherme Rambo](https://github.com/insidegui/AudioCap), adapted to provide a command-line interface for system audio capture. We extend our thanks to the original author for their work in documenting and implementing Apple's new audio capture APIs.

## Future Plans

- Have ideas? Make an issue!