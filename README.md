<p align="center">
  <img src="docs/banner.png" alt="Peasy, a to-do list in your Mac's menu bar">
</p>

**Peasy** is a small to-do list that lives in the macOS menu bar. Click the sprout, jot a task down, get back to work.

## Features

- **Menu bar panel.** Opens under the sprout with a click. Next to the sprout, how many tasks are left today.
- **Today, All and projects.** Today gathers everything planned for today or earlier. Each project has its own color.
- **Dates and reminders.** Pick a day and an optional time. Overdue tasks stay in Today, marked in red.
- **Quick add.** ⌃⌥N in any app opens a small window for a new task.
- **Keyboard.** ↑/↓ to select, Space to complete, Return to edit, ⌘N for a new task.
- **Sync.** iCloud across your Macs, or any synced folder (Dropbox, Google Drive, Syncthing) where iCloud isn't an option.
- **Tasks with Claude.** Claude Code adds the tasks only you can do, like adding a secret or checking a build on a device, and works on the ones you hand to it. A built-in MCP server connects Claude Desktop and Claude Code.
- **Updates.** Peasy checks for new versions and installs them in a click.
- **English and Russian**, dark and light themes.

<p align="center">
  <img src="docs/quick-add.png" alt="Quick add window with a new task, a project and Today picked">
  <br>
  <sub>Quick add: ⌃⌥N in any app, type, press Return.</sub>
</p>

## Install

Download the latest disk image from [Releases](https://github.com/artdima/peasy/releases), open it and drag Peasy to Applications. Peasy needs macOS 14 or later.

## Build

You need Xcode 26 or later. Open `Peasy.xcodeproj` and run.

iCloud sync works in builds signed with the iCloud container. To use your own team, change `iCloud.com.artdima.Peasy` in `Peasy/Peasy.entitlements` and in `CloudSync.containerIdentifier`. Without the container, Peasy keeps tasks on the Mac.

Updates come through Sparkle, see [docs/releasing.md](docs/releasing.md).

## Connect Claude

Under **Claude access** in Settings → General choose **Full Access**, or **Read Only** if Claude should only see your tasks. Then:

- **Claude Desktop:** click Copy Config, paste it in Settings → Developer → Edit Config and restart Claude.
- **Claude Code:** click Copy Command and run it in Terminal.

Peasy has to be running while Claude uses it.

### Working with Claude

- Claude Code finds the project named like its folder, so in a repository called `peasy` it works with the Peasy project.
- When Claude reaches a step only you can do, it adds a task for you with a note and a link. It shows a spark in the list.
- To hand a task to Claude, write `@claude` in its title or choose **Hand to Claude** in its menu. Then ask Claude Code to take your Peasy tasks. It marks a task as in progress, finishes it with a note of what it did, or hands it back with a question.
- Peasy notifies you when Claude needs help and, if you turn it on in Settings, when it finishes a task. Claude's tasks don't count in the sprout's number.

## License

MIT, see [LICENSE](LICENSE).
