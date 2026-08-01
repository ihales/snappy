# Snappy

Snappy is a small, native macOS window snapper. Drag another app's window to a
configured hotspot, release it, and Snappy moves the window into the matching
percentage-based frame.

Each hotspot controls:

- its X/Y trigger position as a percentage of the display;
- the destination X/Y/width/height as percentages of the usable display area;
- optional minimum and maximum display widths, in macOS logical points.

Drop zones are fixed-depth strips along display edges. One app-wide edge-length
setting controls how tall side zones are and how wide top or bottom zones are.
Zones centered near a corner wrap continuously onto the adjacent edge, so both
sides of that corner activate the same snap. When zones overlap, the one whose
center is closest to the pointer wins. In the visual editor, drag the orange
zone around the display edge; drag or resize the blue frame to edit the
resulting window position and size.

The defaults are Left Half, Maximize, and Right Half. Hotspots are stored in
`UserDefaults` and can be added, duplicated, edited, or deleted in the app.

## Keyboard mode

Press `Control-Option-E` to capture the currently focused window and open a
short-lived Snappy mode. Press a hotspot's assigned letter or number to snap
the window, use an arrow key to move it to the neighboring display while
keeping Snappy mode open, or press Escape to cancel. The mode also closes after
three seconds of inactivity.

The default hotspots use `1`, `2`, and `3`. Each key can be changed or cleared
in the hotspot editor; duplicate assignments are highlighted and will not run
until the conflict is resolved.

## Run

```sh
./script/build_and_run.sh
```

The script builds a SwiftPM executable, stages `dist/Snappy.app`, and opens the
app as a normal macOS application. `--verify`, `--debug`, `--logs`, and
`--telemetry` modes are also available.

Run the framework-free model checks with:

```sh
./script/test.sh
```

Snappy needs Accessibility access because macOS protects window position and
size changes. Use **Grant Access** in the app, then enable Snappy in **System
Settings → Privacy & Security → Accessibility**.

The menu bar icon is optional. Turn it off in Snappy Settings; the regular Dock
app remains available. Snappy can also register itself as a macOS login item
using **Start Snappy at login** in Settings. If macOS requires approval, Snappy
links directly to **System Settings → General → Login Items**.
