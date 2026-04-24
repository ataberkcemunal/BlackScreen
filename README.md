# BlackScreen

[⬇️ Download for macOS](https://github.com/ataberkcemunal/BlackScreen/releases/latest)

BlackScreen is a minimal native macOS utility for MacBook users with an external monitor.

It is designed for night-time movie and TV watching. When your MacBook is connected to an external display, the built-in MacBook screen can create distracting light in a dark room. BlackScreen blacks out only the built-in MacBook display while keeping the external monitor usable.

## Features

- Blacks out only the built-in MacBook display
- Keeps external monitors usable
- Attempts to set built-in display brightness to minimum on launch
- Restores brightness when clicked
- Smooth fade-in and fade-out
- No Dock icon while running
- No menu bar while running
- Click anywhere on the black screen to quit
- Lightweight native macOS app written in Swift
- Buildable from Terminal without an Xcode project

## Build

```bash
./build.sh
```

## Run

```bash
open BlackScreen.app
```

## Install

```bash
mv BlackScreen.app /Applications/
```

## Requirements

- macOS
- Swift compiler

## Notes

Brightness control on macOS may behave differently depending on system version and hardware. BlackScreen still shows a fullscreen black overlay on the built-in display even if brightness control is unavailable.

## License

MIT
