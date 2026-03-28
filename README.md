<p align="center">
  <img src="Peasy/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="128" alt="Peasy icon">
</p>

<h1 align="center">Peasy</h1>

<p align="center">Little tasks, big growth. A tiny to-do list that lives in your MacBook's notch.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14+-000000?style=flat-square&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/UI-SwiftUI-1575F9?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/data-SwiftData-5E5CE6?style=flat-square" alt="SwiftData">
  <img src="https://img.shields.io/badge/dependencies-none-2EA043?style=flat-square" alt="No dependencies">
</p>

## What's inside

| Feature | What it does |
| --- | --- |
| **Notch panel** | Hover over the notch and the panel unfolds from it; move away or press Esc to fold it back. |
| **Projects** | Tasks live in projects. Switch with the chips in the header or ⌘1…⌘9, rename and delete from the context menu. |
| **Quick input** | Type a task and press Return. The panel takes the keyboard without activating Peasy, so the app you were in stays in front. |
| **Keyboard** | ↑/↓ select, Space completes, Return edits, ⌘⌫ deletes, ⌘Z undoes, ⌘N jumps back to input. |
| **Reorder** | Drag tasks inside a project and projects inside the header. |
| **Any display** | Built-in display, main display or the one with the pointer. Macs without a notch get a small black island instead. |
| **Settings** | Open at login, display, open delay, completed tasks on or off. English and Russian. |

## Build

```sh
# Xcode 26+, runs on macOS 14+
open Peasy.xcodeproj
xcodebuild -project Peasy.xcodeproj -scheme Peasy -destination 'platform=macOS' test
```

## Architecture

```
Peasy/
├── App/            entry point, AppDelegate wiring, test detection
├── Notch/          NSPanel, notch geometry, hover tracking, shape, view model, key handling
├── Features/
│   ├── Tasks/      panel content, task list, rows, quick input
│   ├── Projects/   project switcher, first-project screen
│   └── Settings/   settings window, launch at login, panel preferences
├── Data/           SwiftData models, TaskStore, fractional ordering
└── Resources/      asset catalog, string catalog
PeasyTests/         Swift Testing suites
```

AppKit owns the window and the mouse, SwiftUI draws everything inside the panel. Views read data through `@Query` and relationships, and change it only through `TaskStore`. The panel controller talks to SwiftUI through `NotchViewModel`: state, layout size and keyboard commands.

## Decisions worth explaining

- **A non-activating `NSPanel` above the menu bar.** It becomes the key window without activating Peasy, so typing goes to the panel while the previous app stays active. On collapse the panel resigns key and input returns.
- **Global mouse monitor, not a tracking area.** The collapsed panel ignores mouse events so clicks still reach the menu bar. Watching `mouseMoved` globally needs no Accessibility permission. While the pointer is inside, a short timer catches exits that the monitors miss.
- **The window follows the panel's size.** Transparent margins would swallow clicks, so the window grows before the unfold animation and shrinks after the fold.
- **Models are CloudKit-ready from day one.** Every property has a default or is optional, relationships are optional with inverses, nothing is unique. Turning on sync is a configuration change, not a migration.
- **Fractional ordering.** Moving a task rewrites one record's `order`; the list is renumbered only when gaps get too small. Fewer writes means fewer sync conflicts.
- **Nothing is created on first launch.** A seeded default project would be duplicated on every Mac once iCloud sync is on, so the first project is the user's.
- **Own key handling.** An agent app has no Edit menu, so the panel routes ⌘X, ⌘C, ⌘V, ⌘A and ⌘Z itself, and a local key monitor handles navigation.

## Tests

`PeasyTests` uses Swift Testing and covers notch geometry for notched, offset and notch-less screens, display choice including a closed lid, models with cascade delete, and `TaskStore`: creation order, empty input, completion, moves, repeated moves that force renumbering, clearing completed tasks.

## Known limitations

- iCloud sync is not switched on yet: it needs a development team and the CloudKit container.
- The panel takes the keyboard as soon as it unfolds, even if you were typing elsewhere.
- In full-screen apps the panel still appears at the top of the screen.
- Open at login is reliable only for a signed build in `/Applications`.
