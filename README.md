# blank slate

This is a simple expressive journaling app.

Write for 20 minutes per day, at the end of the 20 minutes everything is wiped. Your writing is not saved, not to disk, not to the cloud, not to your clipboard, not even screenshots.

This writing is meant to disappear.

Built by Diego, released under MIT license.

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

## build

```
./build.sh
```

produces `BlankSlate.app`. open it.

requires macOS 13+.
