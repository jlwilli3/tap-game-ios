# TapGame

**A high-fidelity native iOS endless runner** — tap to jump, dodge neon obstacles, and chase a personal best. Built entirely in SwiftUI with a retro arcade look: dark void, cyan glow, magenta hazards, and smooth motion. No web views. No third-party game engines.

TapGame is a client-side SwiftUI experience: a `TimelineView` + `Canvas` loop drives the player and incoming blocks, while a premium main menu and skins shop wrap the run in a polished arcade shell.

---

## Features

- **Native SwiftUI engine** — gameplay, HUD, menus, and shop live in one SwiftUI client (`ContentView.swift`)
- **120 FPS timeline loop** — `TimelineView(.animation)` updates physics and rendering every frame
- **Responsive touch controls** — tap anywhere on the arena to jump; grounded jumps only
- **Local persistence via UserDefaults** — absolute high score survives app relaunch
- **Zero backend overhead** — score, physics, and UI run entirely on-device
- **Built-in premium shop monetization** — **Unlock Skins** opens your Stripe Payment Link from the main menu

---

## Technical stack

| Layer | Choice |
| --- | --- |
| Language | Swift |
| UI & game loop | SwiftUI (`TimelineView`, `Canvas`, Observation) |
| Platform | iOS 18+ |
| IDE | Xcode |
| Agent workflow | Cursor |

Supporting APIs: `UserDefaults` for best score, `Link` for Stripe checkout, UIKit haptics for jump and game-over feedback.

---

## Run locally

### Requirements

- macOS with **Xcode** (iOS 18+ SDK)
- An iPhone simulator or a signed physical device

### Open and run

```bash
cd /path/to/TapGame
open TapGame.xcodeproj
```

In Xcode:

1. Select the **TapGame** scheme.
2. Choose an **iPhone simulator** (or a connected device).
3. Press **Run** (`⌘R`).

### Stripe skins link

Replace the payment-link constant in `TapGame/ContentView.swift` with your live Stripe URL:

```swift
static let stripePaymentLinkText = "https://buy.stripe.com/test_TapGameUnlockSkins"
```

### How to play

1. Launch the app → **START GAME**.
2. Tap anywhere to jump over incoming blocks.
3. Score increases for each obstacle you clear; speed ramps with score.
4. Colliding ends the run. Beat your **BEST** — it is stored locally.

---

## Project layout

```
TapGame/
├── TapGame.xcodeproj
├── README.md
└── TapGame/
    ├── TapGameApp.swift      # App entry
    ├── ContentView.swift     # Menu, shop, arena, physics
    └── Assets.xcassets
```

---

## License

Private project. All rights reserved unless otherwise noted.
