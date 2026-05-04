# Aerovibes Flight Counter 1.0 User Guide

Aerovibes Flight Counter 1.0 is an Ethos widget that keeps track of how many flights have been made on a model. It shows a **Today** count for flights made on the current day and a **Lifetime** count for the full running total, including any starting count entered by the user.

A flight is counted when the configured trigger switch stays active long enough to pass the selected trigger delay. After one flight is counted, the widget will not count another one until the radio is rebooted, which helps prevent accidental double-counting during the same session.

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

### Starting Lifetime Count

Use this field if the model already had flights before the widget was installed. The number entered here is added to the counted lifetime total so the displayed lifetime value starts from the correct overall number.

Example: if the model already had 23 flights before using the widget, enter `23` as the Starting Lifetime Count. If the widget later counts 5 additional flights, the displayed lifetime total will be 28.

### Reset all data on reboot

This is a one-time reset option. Turn it on, reboot the radio once, and the widget will clear the saved `Today`, `Lifetime`, and `Starting Lifetime Count` data, then automatically clear the reset request so later reboots do not keep resetting the counter.

### Border

This turns the border around the widget display on or off. It only affects appearance and does not change counting behavior.

## Counting behavior

The widget is designed to count only one flight per radio power cycle. Once a flight has been counted, another one will not be added until the radio is turned off and back on again.

This behavior is intentional and helps avoid false or duplicate flight counts from the trigger switch being toggled more than once during the same session. For pilots who power the radio on at the start of a flight session and off again afterward, this provides a simple and reliable safeguard.

## Installation

### Install manually on the SD card

1. Open the SD card used by the radio.
2. Copy the `FlightCount_1_0` folder into the `scripts` folder on the card so the final script path is `scripts/FlightCount_1_0/main.lua`.
3. Safely eject the card and start the radio.
4. Open the model where the widget will be used.
5. Go to screen configuration, choose a widget location, and select **Aerovibes Flight Counter 1.0**.
6. Open the widget configuration page and set the Trigger Switch and any other options.

### Install with Ethos Suite

1. Prepare a ZIP file that contains the final SD card folder structure directly.
2. The ZIP should contain `scripts/FlightCount_1_0/main.lua` at the top path inside the archive, not inside an extra parent folder.
3. In Ethos Suite, open the **Lua Library** tab.
4. Choose **Install lua script** and select the ZIP file.
5. Let Ethos Suite copy the script to the radio storage, then configure the widget on the desired model screen in Ethos.

## ZIP structure for Ethos Suite

The ZIP archive should contain this layout:

```text
scripts/
└── FlightCount_1_0/
    ├── main.lua
    └── Files/
```

The `Files` folder may be empty when first packaged. The widget creates and updates model-specific text files there automatically as it runs.

When making the ZIP, zip the **contents** of the package folder so that `scripts/` is the first folder visible inside the archive. This avoids creating an extra top-level folder that can cause the install path to be wrong.

## Tips

- Use a trigger that happens once per real flight, not a switch that is toggled often on the ground.
- Use a small trigger delay if brief accidental switch activation is possible.
- Use **Starting Lifetime Count** only to account for older flights that happened before the widget was installed.
- Use **Reset all data on reboot** only when a full reset is desired; it is not needed for normal operation.
