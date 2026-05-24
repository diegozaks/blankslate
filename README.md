# blank slate

This is a simple expressive journaling app.

Write for 20 minutes per day, at the end of the 20 minutes everything is wiped. Your writing is not saved, not to disk, not to the cloud, not to your clipboard, not even screenshots.

This writing is meant to disappear.

Built by Diego, released under MIT license.

## download

Grab the latest release from [releases](https://github.com/diegozaks/blankslate/releases/latest). Unzip and drag `BlankSlate.app` to your Applications folder.

The app isn't code-signed, so the first time you open it macOS will warn you. Right-click `BlankSlate.app` → **Open** → **Open** in the dialog. Only needed once.

Requires macOS 13+.

## commands

type any of these and hit return -- the line gets eaten, the action runs:

| command   | what it does                  |
|-----------|-------------------------------|
| `/type`   | typography panel              |
| `/dark`   | dark mode                     |
| `/light`  | light mode                    |
| `/pause`  | pause the timer               |
| `/reset`  | wipe and restart              |
| `/about`  | what this is                  |
| `/help`   | list all commands             |

press `esc` to close any open panel.

## build from source

```
./build.sh
```

produces `BlankSlate.app`. open it.
