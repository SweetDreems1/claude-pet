# Pixel Pet

A tiny pixel mascot for macOS that lives on top of your windows.

- walks along window edges and rides them when they move
- falls with a splat when the window under it disappears
- sleeps in its little house in the corner; click the house to pet it (♥)
- wears a nightcap while Dark Mode is on
- pops up an app's icon when a new Dock badge appears (Telegram, Mail, …)
- follows you across desktops

![petting](preview/petting.png)
![splat](preview/splat.png)

## Build

Requires Xcode command line tools.

```bash
./build.sh
```

Builds `Pixel Pet.app`, copies it to `/Applications` and launches it.
