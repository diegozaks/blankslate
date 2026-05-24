# blank slate

a private journaling app. 20 minutes a day, then it's gone.

nothing gets saved -- not to disk, not to the cloud, not to your clipboard. text only lives in memory while you're writing.

at 0:00 everything wipes. screenshots come back black, screen sharing too. no copy, no paste, no select -- you can only type forward, or backspace one character at a time.

write like nobody's reading. because nobody is, including you. let your thoughts roam. say the thing you wouldn't say anywhere else.

a kind of meditation. 20 minutes, then a blank slate.

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
