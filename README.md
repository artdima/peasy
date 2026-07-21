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
  <img src="https://img.shields.io/badge/notch-NotchKit-2EA043?style=flat-square" alt="NotchKit">
</p>

## What's inside

| Feature | What it does |
| --- | --- |
| **Notch panel** | Hover over the notch and the panel unfolds from it; move away to fold it back. Click into the panel to type: then it stays open until you click elsewhere or press Esc. The pin in the header keeps it open even then. |
| **Today, Inbox, projects** | Today collects the tasks flagged for today from every list. Inbox holds tasks without a project. Projects get a color each; rename, reorder and delete them from the list. |
| **Two layouts** | Vertical: projects in a column on the left. Horizontal: projects as tabs on top, wrapping onto new rows when they run out of room. Switch in Settings. |
| **Resizable** | Drag the bottom-right corner to resize the panel; each layout remembers its size. Reset from the context menu. |
| **Focus and Sprout** | Press ▶ on a task to focus on it. The panel folds away and Sprout, a little seedling, sits in the notch next to the task; hover him to see its name. Finish the task and he celebrates. |
| **Collapsed notch** | A progress ring and the number of tasks left for today, the focused task, or a short "Added" after a quick add. |
| **Quick add** | ⌃⌥N from any app opens a small window in the middle of the screen. Type, pick a project or Today, press Return. The shortcut is configurable. |
| **Keyboard** | ↑/↓ select, Space completes, Return edits, ⌘⌫ deletes, ⌘Z undoes, ⌘N jumps to the new task field, ⌘1…⌘9 switch lists. |
| **Reorder** | Drag tasks inside a list and projects inside the sidebar or the tab bar. |
| **iCloud sync** | Projects and tasks follow your Apple ID to every Mac. Settings shows the sync status and lets you turn sync off. Without iCloud Peasy keeps everything on this Mac. |
| **Any display** | Built-in display, main display or the one with the pointer. Macs without a notch get a small black island instead. |
| **Settings** | iCloud sync, layout, multiline tasks, expand on hover or on click, Today indicator, Sprout, display, quick add shortcut, open at login. English and Russian. |

## Build

```sh
# Xcode 26+, runs on macOS 14+
open Peasy.xcodeproj
xcodebuild -project Peasy.xcodeproj -scheme Peasy -destination 'platform=macOS' -allowProvisioningUpdates test
```

### iCloud sync

`Peasy/Peasy.entitlements` turns on iCloud with CloudKit (container `iCloud.com.artdima.Peasy`) and push notifications, which CloudKit uses to report changes from other Macs. The first build needs the team's Apple account in Xcode → Settings → Accounts: Xcode registers the container and creates the provisioning profile. From the command line, add `-allowProvisioningUpdates` to `xcodebuild`.

Debug builds use the Development environment in CloudKit, so real data is never touched. Before the first public build, deploy the CloudKit schema to Production in CloudKit Console.

To build under another team, change the team in Signing & Capabilities and the container in `CloudSync.containerIdentifier` and the entitlements. A build signed without the iCloud entitlement keeps tasks on this Mac, and Settings says so.

## Architecture

```
Peasy/
├── App/            entry point, AppDelegate wiring, global hotkey
├── Notch/          NotchKit presenter setup, view model, key handling, display choice
├── Features/
│   ├── Panel/      header, shared colors and controls
│   ├── Tasks/      panel content, task list, rows, new task field
│   ├── Projects/   sidebar and tab bar
│   ├── Island/     collapsed notch content, Sprout, hover cloud
│   ├── QuickAdd/   quick add window
│   └── Settings/   settings window, shortcut recorder, launch at login
├── Data/           SwiftData models, lists, TaskStore, fractional ordering
└── Resources/      asset catalog, string catalog
PeasyTests/         Swift Testing suites
```

[NotchKit](https://github.com/duongductrong/NotchKit) owns the window and the morphing shape. `NotchController` configures it, decides when to open on hover, routes the keyboard and keeps the panel on the chosen display. Views read data through `@Query` and relationships, and change it only through `TaskStore`. `SyncMonitor` follows CloudKit events and the iCloud account; when sync is switched, `AppDelegate` reopens the store and hands the new container to the panel and the quick add window. The controller talks to SwiftUI through `NotchViewModel`: the selected list and task, editing state, focus, celebrations and what the collapsed notch shows.

## Decisions worth explaining

- **NotchKit for the window and the shape.** A hand-rolled panel crashed in a constraint-update loop when SwiftUI resized its window, and lost hover at the top pixel row of the screen. NotchKit keeps one fixed-size window, morphs a single shape inside it and hit-tests the visible ink only.
- **Keyboard only after a click.** A hover-opened panel does not take the keyboard, so drifting to the top of the screen never steals keystrokes. The first click inside makes the panel key and keeps it open until a click elsewhere or Esc.
- **Own outside-click handling.** NotchKit can replay the dismissing click to the app underneath; Peasy turns that off and collapses from a passive global monitor instead, so a click outside is delivered exactly once.
- **Models are CloudKit-ready from day one.** Every property has a default or is optional, relationships are optional with inverses, nothing is unique. Turning on sync is a configuration change, not a migration.
- **Sync turns itself on.** At launch Peasy reads its own entitlements: a build signed with the iCloud container syncs, an unsigned one stays local. The project builds and tests without a team, and nothing crashes on a missing entitlement.
- **Sync now reopens the store.** SwiftData has no call to force a sync. Reopening the store makes CloudKit set up, import and export again, which is what the button promises.
- **Fractional ordering.** Moving a task rewrites one record's `order`; the list is renumbered only when gaps get too small. Fewer writes means fewer sync conflicts.
- **Nothing is created on first launch.** A seeded default project would be duplicated on every Mac once iCloud sync is on, so Inbox is virtual and the first project is the user's.
- **Own key handling.** An agent app has no Edit menu, so the panel routes ⌘X, ⌘C, ⌘V, ⌘A and ⌘Z itself, and a local key monitor handles navigation.
- **Today is a flag, Inbox is a query.** A task belongs to at most one project and can also be marked for today, so Today never duplicates data. Inbox is simply the tasks without a project; there is no Inbox record to duplicate across Macs.
- **Sprout runs in the render server.** He is drawn with Core Animation shape layers, so his idle animation costs nothing on the main thread and stays smooth while the app is busy. Reduce Motion stops it.
- **Carbon for the global shortcut.** `RegisterEventHotKey` works without Accessibility permission, unlike a global key monitor.

## Tests

`PeasyTests` uses Swift Testing and covers display choice including a closed lid, models with cascade delete, the panel surviving opening and adding tasks and a store reload, sync status from CloudKit events, errors and account changes, CloudKit rules for the models, and `TaskStore`: creation order and project colors, empty input, Today across lists and its progress, completion, moves, repeated moves that force renumbering, clearing completed tasks.

## Known limitations

- After signing out of iCloud or switching Apple ID, CloudKit may clear this Mac's copy of the previous account's tasks. They come back when you sign in to that account again; changes that never reached iCloud are lost.
- A long list scrolls inside the panel.
- In full-screen apps the panel still appears at the top of the screen.
- Open at login is reliable only for a signed build in `/Applications`.
