# Flight Counter

DLG flight tally widget for FrSky Ethos. Built and tested on a FrSky X20RS
running Ethos 26.1.1. Inspired by vprheli's Ethos Lua widgets.

Flight Counter is an Ethos widget that keeps track of how many flights
have been made on a model. It shows a **Today** count for flights made on
the current day and a **Lifetime** count for the full running total,
including any starting count entered by the user. A flight is counted
when the configured trigger switch stays active long enough to pass the
selected trigger delay.

## What the widget shows

- **Today** — the number of flights counted for the current day. Resets
  automatically when the date changes.
- **Lifetime** — the stored lifetime tally plus the **Starting Lifetime
  Count** value. Keeps growing until the counter data is reset.

## Trigger delay countdown

If a trigger delay greater than zero is set, the widget gives visible
feedback while the delay is counting down: the displayed text blinks
between orange and green until the delay completes. This is useful when
the trigger switch may be active briefly without meaning a real flight
has started — if the switch is released before the delay completes, the
countdown is canceled and starts over the next time the trigger is
activated.

## Settings

Long-press the widget on a model screen (native Ethos "Configure" option)
to reach these:

- **Trigger Switch** — the switch that tells the widget when a flight may
  be starting. Any physical or logical switch supported by Ethos can be
  used. Pick one that happens once per flight and is unlikely to be
  toggled accidentally (an arming switch, gear switch, or similar).
- **Trigger Delay** — how long the trigger switch must remain active
  before a flight is counted, in seconds. `0` counts immediately when the
  trigger becomes active.
- **One count per power cycle** — **On**: the widget counts only one
  flight until the radio is power-cycled. **Off**: the widget can count
  another flight in the same session, but only after the trigger switch
  has been released and activated again — it never double-counts a single
  continuous activation either way.
- **Starting Lifetime Count** — use this if the model already had flights
  before the widget was installed; it's added to the counted lifetime
  total. Example: 23 prior flights + 5 counted since = a displayed
  lifetime of 28.
- **Reset all data on reboot** — a one-time reset. Turn it on, reboot the
  radio once, and the widget clears the saved `Today`, `Lifetime`, and
  `Starting Lifetime Count` data, then automatically clears the reset
  request so later reboots don't keep resetting the counter.
- **Border** — toggles a border around the widget display. Appearance
  only, doesn't affect counting.

## Installation

### Install with Ethos Suite

**Known limitation:** whether Ethos Suite's installer merges into an
existing `Files/` folder or replaces it wholesale on reinstall/upgrade is
untested. If you're updating an existing install with real flight counts,
back up your `scripts/FlightCount/Files/` folder first — if the counts
reset after updating, restore your `.txt` files from that backup.

1. Download the release ZIP (see the
   [Releases page](https://github.com/gjawhar/FlightCount/releases)) —
   it's already shaped the way Ethos Suite expects, no repacking needed.
2. In Ethos Suite, open the **Lua Library** tab.
3. Choose **Install lua script** and select the ZIP file.
4. Let Ethos Suite copy the script to the radio storage, then assign the
   widget to a model screen (it will appear as "Flight Counter" in the
   widget picker) and open its Settings to set the Trigger Switch and any
   other options.

ZIP structure for Ethos Suite:

```
scripts/
└── FlightCount/
    ├── main.lua
    └── Files/
```

`Files/` must exist (even empty) because the widget stores model-specific
text files there automatically as it runs.

### Install manually via the SD card or internal storage

Ethos radios can store scripts either on a removable SD card or in the
transmitter's internal storage — use whichever your radio is set up with.

1. Connect the radio to your computer and open its storage (SD card or
   internal storage, depending on your setup) in your file manager.
2. Copy the `FlightCount` folder into the `scripts` folder there so the
   final script path is `scripts/FlightCount/main.lua`.
3. Safely disconnect/eject and start (or reboot) the radio.
4. Open the model where the widget will be used, go to screen
   configuration, choose a widget location, and select "Flight Counter".
5. Open the widget configuration page and set the Trigger Switch and any
   other options.

## Upgrading from older versions

If an older installation used the folder `FlightCount_1_0`, saved counter
files from that older folder won't automatically be read after moving to
`FlightCount`, because the save path has changed. To keep old data, move
the model text files from `scripts/FlightCount_1_0/Files/` to
`scripts/FlightCount/Files/` before running the new version.

## Tips

- Use a trigger that happens once per real flight, not a switch that's
  toggled often on the ground.
- Use a small trigger delay if brief accidental switch activation is
  possible.
- Use **Starting Lifetime Count** only to account for older flights that
  happened before the widget was installed.
- Use **Reset all data on reboot** only when a full reset is desired —
  it's not needed for normal operation.

## Feedback

Found a bug, or something that doesn't behave the way you'd expect?
Please open an issue on GitHub rather than emailing me directly — that
way bugs, discussion, and fixes all stay tracked in one place other pilots
can also see:

**https://github.com/gjawhar/FlightCount/issues**
