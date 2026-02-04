# DarwinSniffer
[![Xcode - Build and Analyze](https://github.com/OakyMacintosh/DarwinSniffer/actions/workflows/objective-c-xcode.yml/badge.svg)](https://github.com/OakyMacintosh/DarwinSniffer/actions/workflows/objective-c-xcode.yml)

DarwinSniffer is a macOS hardware detection tool that generates OpenCore Simplify compatible reports. It can print hardware details to the console and export a JSON report.

**Features**
1. Detects CPU, GPU, memory, storage, network, audio, USB, and system info
2. Generates an OpenCore Simplify compatible JSON report
3. CLI flags for focused output and verbose mode

**Requirements**
1. macOS
2. Xcode (for `xcodebuild`)

**Build**
Use the build script:
```bash
python3 DarwinSniffer/Scripts/build.py
python3 DarwinSniffer/Scripts/build.py --release
python3 DarwinSniffer/Scripts/build.py --debug
python3 DarwinSniffer/Scripts/build.py --output /path/to/output
```

Or build directly:
```bash
xcodebuild -project DarwinSniffer.xcodeproj -scheme DarwinSniffer -configuration Release clean build
```

**Run**
```bash
./Build/DarwinSniffer
./Build/DarwinSniffer --verbose
./Build/DarwinSniffer --cpu
./Build/DarwinSniffer --gpu --verbose
./Build/DarwinSniffer --output ~/Desktop/hardware_report.json
```

**CLI Options**
1. `-o`, `--output <path>`: Output file path (default: `hardware_report.json`)
2. `-v`, `--verbose`: Show detailed output
3. `-h`, `--help`: Show help
4. `--cpu`: Show only CPU information
5. `--gpu`: Show only GPU information
6. `--memory`: Show only memory information
7. `--storage`: Show only storage information
8. `--network`: Show only network information
9. `--audio`: Show only audio information
10. `--all`: Show all hardware (default)

**Output**
The report is written as pretty‑printed JSON and is compatible with OpenCore Simplify.
