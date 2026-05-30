# Aerovibes Flight Counter 1.1 User Guide
# Inspired by vprheli’s ETHOS Lua widgets
Aerovibes Flight Counter 1.1 is an Ethos widget that keeps track of how many flights have been made on a model. It shows a **Today** count for flights made on the current day and a **Lifetime** count for the full running total, including any starting count entered by the user.

A flight is counted when the configured trigger switch stays active long enough to pass the selected trigger delay.

## What the widget shows

The widget displays two values:

- **Today**: the number of flights counted for the current day.
- **Lifetime**: the full total, made up of the stored lifetime tally plus the **Starting Lifetime Count** value.

The `Today` value resets automatically when the date changes. The `Lifetime` value continues to grow unless the counter data is reset.

## Everyday use

In normal use, the widget is mostly automatic. Once the trigger switch has been set, the widget waits for that trigger to become active and then counts a flight after the configured delay has passed.

A common setup is to use an arming switch, gear switch, or another switch that only becomes active when the model is truly in flight or committed to flight. The best trigger is one that happens once per flight and is unlikely to be toggled accidentally.

## Trigger delay countdown

If a trigger delay greater than zero is set, the widget gives visible feedback while the delay is counting down. During that time, the displayed text blinks between orange and green until the delay completes.

This is useful when the trigger switch may be active briefly without meaning that a real flight has started. If the switch is released before the delay completes, the countdown is canceled and starts over the next time the trigger is activated.

## Settings

### Trigger Switch

This is the switch that tells the widget when a flight may be starting. Any physical or logical switch supported by Ethos can be used.

### Trigger Delay

This sets how long the trigger switch must remain active before a flight is counted. A value of `0` counts immediately when the trigger becomes active, while a larger value requires the trigger to remain on for that many seconds.

### One count per power cycle

This setting controls how often the widget is allowed to count flights during a single radio power session.

- **On**: the widget counts only one flight per power cycle.
- **Off**: the widget can count again in the same power session after the trigger switch goes inactive and then becomes active again.

With this setting turned off, the widget still counts only once per trigger activation. It will not keep counting repeatedly while the trigger remains continuously active.

### Starting Lifetime Count

Use this field if the model already had flights before the widget was installed. The number entered here is added to the counted lifetime total so the displayed lifetime value starts from the correct overall number.

Example: if the model already had 23 flights before using the widget, enter `23` as the Starting Lifetime Count. If the widget later counts 5 additional flights, the displayed lifetime total will be 28.

### Reset all data on reboot

This is a one-time reset option. Turn it on, reboot the radio once, and the widget will clear the saved `Today`, `Lifetime`, and `Starting Lifetime Count` data, then automatically clear the reset request so later reboots do not keep resetting the counter.

### Border

This turns the border around the widget display on or off. It only affects appearance and does not change counting behavior.

## Counting behavior

The widget can now work in two different ways depending on the **One count per power cycle** setting.

When **One count per power cycle** is turned on, the widget counts only one flight until the radio is turned off and back on again.

When **One count per power cycle** is turned off, the widget can count another flight in the same session, but only after the trigger switch has been released and activated again. This helps avoid duplicate counts while the same trigger event is still active.

## Installation

### Install from GitHub Code > Download ZIP

If you download the repository using **Code > Download ZIP**, GitHub downloads a snapshot of the repository rather than a custom install package.[cite:19][cite:25]

After downloading:

1. Unzip the downloaded file on your computer.
2. Open the top-level downloaded folder, which may be named something like `FlightCount-main`.
3. Inside that folder, locate the `scripts` folder.
4. Copy the `FlightCount` folder into the `scripts` folder on your radio SD card.
5. Make sure the final installed path is `scripts/FlightCount/main.lua`.
6. Make sure the `Files` folder is also present at `scripts/FlightCount/Files/`.

The widget saves model-specific text files in the `Files` folder, so that folder must exist for saving to work.[file:1]

### Install manually on the SD card

1. Open the SD card used by the radio.
2. Copy the `FlightCount` folder into the `scripts` folder on the card so the final script path is `scripts/FlightCount/main.lua`.
3. Safely eject the card and start the radio.
4. Open the model where the widget will be used.
5. Go to screen configuration, choose a widget location, and select **Aerovibes Flight Counter 1.1**.
6. Open the widget configuration page and set the Trigger Switch and any other options.

### Install with Ethos Suite

1. Prepare a ZIP file that contains the final SD card folder structure directly.
2. The ZIP should contain `scripts/FlightCount/main.lua` at the top path inside the archive, not inside an extra parent folder.
3. In Ethos Suite, open the **Lua Library** tab.
4. Choose **Install lua script** and select the ZIP file.
5. Let Ethos Suite copy the script to the radio storage, then configure the widget on the desired model screen in Ethos.

## ZIP structure for Ethos Suite

The ZIP archive should contain this layout:

```text
scripts/
└── FlightCount/
    ├── main.lua
    └── Files/
```

The `Files` folder may be empty when first packaged, but it must exist because the widget stores model-specific text files there automatically as it runs.[file:1]

When making the ZIP, zip the **contents** of the package folder so that `scripts/` is the first folder visible inside the archive. This avoids creating an extra top-level folder that can cause the install path to be wrong.

## Upgrading from older versions

If an older installation used the folder `FlightCount_1_0`, saved counter files from that older folder will not automatically be read after moving to `FlightCount`, because the save path has changed in the script.[file:1]

To keep old data, move the model text files from:

```text
scripts/FlightCount_1_0/Files/
```

to:

```text
scripts/FlightCount/Files/
```

before running the new version.

## Tips

- Use a trigger that happens once per real flight, not a switch that is toggled often on the ground.
- Use a small trigger delay if brief accidental switch activation is possible.
- Use **Starting Lifetime Count** only to account for older flights that happened before the widget was installed.
- Use **Reset all data on reboot** only when a full reset is desired; it is not needed for normal operation.
- If installing from the GitHub repository ZIP, confirm that the `Files` folder exists after copying the script to the radio.[file:1]
