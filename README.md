<p align="center">
  <img src="Peasy/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="128" alt="Peasy icon">
</p>

<h1 align="center">Peasy</h1>

<p align="center">Little tasks, big growth. A tiny to-do list that lives in your Mac's menu bar.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14+-000000?style=flat-square&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/UI-SwiftUI-1575F9?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/data-SwiftData-5E5CE6?style=flat-square" alt="SwiftData">
</p>

## What's inside

| Feature | What it does |
| --- | --- |
| **Menu bar panel** | Click the pea in the menu bar and the panel opens in a floating window under it, ready for typing. It closes on another click on the pea, a click elsewhere, a switch to another app (⌘Tab, Dock) or Esc. The pin in the header keeps it open on clicks and app switches. Right-click the pea for About, Settings and Quit. |
| **Today, All, projects** | Today collects the tasks planned for today or earlier from every list, and each morning starts without yesterday's finished ones. All shows every task, with or without a project. Projects get a color each; rename, reorder and delete them from the list. |
| **Two layouts** | Vertical: projects in a column on the left. Horizontal: projects as tabs on top, wrapping onto new rows when they run out of room. Switch in Settings. |
| **Resizable** | Drag the bottom-left corner to resize the panel; each layout remembers its size. Reset from the context menu. |
| **Date and time** | The calendar button on a task opens a picker beside it: Today, Tomorrow, This Weekend, Next Week, any day in the calendar, and an optional time. The choice is saved when the picker closes. Late tasks stay in Today marked in red; a task with a time sends a notification. |
| **Menu bar icon** | A pea that grows as today's tasks get done: it sprouts, puts out leaves and a bud, and flowers when the day is complete. Next to it, how many tasks are left today. Also a short "Added" after a quick add. |
| **Quick add** | ⌃⌥N from any app opens a small window in the middle of the screen. Type, pick a project or Today, press Return. The shortcut is configurable. |
| **Keyboard** | ↑/↓ select, Space completes, Return edits, ⌘⌫ deletes, ⌘Z undoes, ⌘N jumps to the new task field, ⌘1…⌘9 switch lists. |
| **Reorder** | Drag tasks inside a list and projects inside the sidebar or the tab bar. |
| **iCloud sync** | Projects and tasks follow your Apple ID to every Mac. Settings shows the sync status and lets you turn sync off. Without iCloud Peasy keeps everything on this Mac. |
| **Settings** | iCloud sync, appearance, layout, multiline tasks, Today indicator, quick add shortcut, open at login. English and Russian. |

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
├── MenuBar/        status item, the floating panel window, view model, key handling
├── Features/
│   ├── Panel/      panel content, header, shared colors and controls
│   ├── Tasks/      task list, rows, new task field, date picker
│   ├── Projects/   sidebar and tab bar
│   ├── Pea/        the pea in the menu bar
│   ├── QuickAdd/   quick add window
│   └── Settings/   settings window, shortcut recorder, launch at login
├── Data/           SwiftData models, lists, TaskStore, fractional ordering
└── Resources/      asset catalog, string catalog
PeasyTests/         Swift Testing suites
```

`MenuBarController` owns the status item and a borderless floating panel under it: `PanelPlacement` works out where the window goes for the item's frame. The controller opens and closes the panel on clicks on the item, routes the keyboard and closes the panel on clicks outside. Views read data through `@Query` and relationships, and change it only through `TaskStore`. `SyncMonitor` follows CloudKit events and the iCloud account; when sync is switched, `AppDelegate` reopens the store and hands the new container to the panel and the quick add window. The controller talks to SwiftUI through `PanelViewModel`: the selected list and task, editing and scheduling state. `Reminders` rebuilds pending notifications from the tasks after every save.

## Decisions worth explaining

- **A floating window, not a popover.** The panel is a non-activating `NSPanel` a few points below the menu bar: it takes the keyboard when it opens, but the app in front stays in front, and its rounded body casts the window's own shadow. An `NSPopover` would add its arrow and chrome and activate the app. The panel's right edge is anchored to the icon, so dragging the bottom-left corner resizes it under the pointer.
- **Opens on a click only.** Hover never opens the panel, so moving the pointer across the menu bar never covers the screen. While it is open the status item keeps the system highlight, like the menu bar's own extras.
- **Own outside-click handling.** The panel collapses from a passive global monitor, so a click outside reaches the app underneath exactly once.
- **Models are CloudKit-ready from day one.** Every property has a default or is optional, relationships are optional with inverses, nothing is unique. Turning on sync is a configuration change, not a migration.
- **Sync turns itself on.** At launch Peasy reads its own entitlements: a build signed with the iCloud container syncs, an unsigned one stays local. The project builds and tests without a team, and nothing crashes on a missing entitlement.
- **Sync now reopens the store.** SwiftData has no call to force a sync. Reopening the store makes CloudKit set up, import and export again, which is what the button promises.
- **Fractional ordering.** Moving a task rewrites one record's `order`; the list is renumbered only when gaps get too small. Fewer writes means fewer sync conflicts.
- **Nothing is created on first launch.** A seeded default project would be duplicated on every Mac once iCloud sync is on, so All is virtual and the first project is the user's.
- **Own key handling.** An agent app has no Edit menu, so the panel routes ⌘X, ⌘C, ⌘V, ⌘A and ⌘Z itself, and a local key monitor handles navigation.
- **Today is a date, All is a query.** A task belongs to at most one project and can also have a planned date, so Today never duplicates data. Older versions kept a Today flag; it is turned into today's date on launch. All is simply every task; there is no list record to duplicate across Macs.
- **The pea runs in the render server.** It is drawn with Core Animation shape layers, so growing into the next stage costs nothing on the main thread. Reduce Motion stops the animation.
- **Carbon for the global shortcut.** `RegisterEventHotKey` works without Accessibility permission, unlike a global key monitor.

## Tests

`PeasyTests` uses Swift Testing and covers where the panel goes for a status item near either screen edge and on a second display, models with cascade delete, the panel surviving opening and adding tasks and a store reload, sync status from CloudKit events, errors and account changes, CloudKit rules for the models, and `TaskStore`: creation order and project colors, empty input, Today across lists and its progress, late and earlier-finished tasks, moving to Today with the time kept, the old Today flag, completion, moves, repeated moves that force renumbering, clearing completed tasks; and which tasks get a reminder.

## Known limitations

- After signing out of iCloud or switching Apple ID, CloudKit may clear this Mac's copy of the previous account's tasks. They come back when you sign in to that account again; changes that never reached iCloud are lost.
- A long list scrolls inside the panel.
- In full-screen apps the menu bar is hidden, so the icon is reachable only when the bar slides in.
- With several displays the panel opens under the icon on the display whose menu bar is active.
- Open at login is reliable only for a signed build in `/Applications`.
