# Getting Started

## Requirements

- **macOS 13.0 (Ventura)** or later
- **Screen Recording** permission in System Settings
- Swift 5.9+ / Xcode 15+ (for unit testing)

## Installation

### Option 1: Download Pre-built Release
Download the latest `ctdoshot-macOS-Universal.zip` from [Releases](https://github.com/TIPC1110/ctdoshot/releases), unzip, and move `ctdoshot.app` to `/Applications`.

### Option 2: Build from Source
```bash
git clone https://github.com/TIPC1110/ctdoshot.git
cd ctdoshot

# Generate stable code-signing cert once:
./scripts/ensure-signing-identity.sh

# Build Universal .app bundle (Intel + Apple Silicon):
./scripts/package-app.sh --universal
open build/ctdoshot.app
```

## First Launch — Screen Recording Permission

1. Open **System Settings → Privacy & Security → Screen Recording**.
2. Enable **ctdoshot**.
3. **Quit fully** (⌘Q) and reopen `ctdoshot.app`.
