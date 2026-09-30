# Power Loss Recovery

This guide describes how to resume an interrupted print using KlipperPLR.

> [!WARNING]
> Power-loss recovery restores the Z coordinate without physically homing the Z axis.
>
> Do not move the Z axis, gantry, bed, or toolhead vertically after a power loss if you intend to recover the print.

---

## How recovery works

During a normal print, KlipperPLR stores:

```text
Original G-code file
Original G-code path
Last reported layer Z height
```

The layer height is supplied by the slicer using:

```gcode
LOG_Z Z={layer_z}
```

After a power loss, KlipperPLR uses this information to generate a new recovery G-code containing the remaining portion of the original print.

---

# After a power loss

## 1. Do not move the Z axis

This is the most important requirement.

KlipperPLR assumes that the physical Z position after power is restored is the same as it was when power was lost.

Do not:

- manually rotate the Z lead screws
- move the gantry vertically
- move a Z-driven bed
- manually move the toolhead in Z
- run `G28 Z`
- run a complete `G28`

X and Y may be homed by KlipperPLR during recovery.

---

## 2. Restore power

Turn the printer back on and wait for:

- the Klipper host to boot
- Klipper to connect to the MCU
- Moonraker to start
- the printer interface to become available

Do not manually home the printer.

---

## 3. Check the interrupted print

Before starting recovery, visually inspect the printer.

Verify that:

- the printed object is still firmly attached to the bed
- the bed has not physically moved
- the Z axis has not moved
- the toolhead can safely home X and Y
- no loose filament or failed print geometry blocks the toolhead
- the printer has no hardware fault

If the print has detached from the bed, recovery should not be attempted.

---

## 4. Start recovery

Run:

```gcode
RESUME_INTERRUPTED
```

KlipperPLR reads the stored print information automatically.

Normally, no parameters are required.

---

# What happens during recovery

When:

```gcode
RESUME_INTERRUPTED
```

is executed, KlipperPLR performs the following process.

### 1. Read the saved state

KlipperPLR reads the stored:

```text
last_file
filepath
power_resume_z
```

values.

---

### 2. Generate the recovery G-code

The original G-code file is analyzed.

KlipperPLR searches for the saved layer marker:

```gcode
;LAYER_CHANGE
;Z:<saved Z>
```

For example:

```gcode
;LAYER_CHANGE
;Z:0.8
```

A new recovery G-code is generated in:

```text
~/printer_data/gcodes/plr/
```

---

### 3. Restore the Z coordinate

The generated recovery file begins with:

```gcode
SET_KINEMATIC_POSITION Z=<saved_z> SET_HOMED=Z CLEAR_HOMED=XY
```

For a saved height of `0.8`, this becomes:

```gcode
SET_KINEMATIC_POSITION Z=0.8 SET_HOMED=Z CLEAR_HOMED=XY
```

This tells Klipper that:

```text
Z = known
X = unhomed
Y = unhomed
```

No physical Z homing movement is performed.

---

### 4. Restore temperatures

KlipperPLR analyzes the original G-code and determines the most recent bed and hotend temperatures before the recovery layer.

The bed and hotend are heated to those temperatures before printing continues.

---

### 5. Restore the extrusion state

KlipperPLR restores the extrusion mode used by the original G-code.

Relative extrusion is restored using:

```gcode
G92 E0
M83
```

For absolute extrusion, the previous extrusion coordinate is reconstructed and restored.

---

### 6. Home X and Y

KlipperPLR executes:

```gcode
G28 X Y
```

Z remains at the reconstructed coordinate.

The printer's homing configuration must allow X and Y to home independently without automatically homing Z.

---

### 7. Restore the bed mesh

KlipperPLR loads:

```gcode
BED_MESH_PROFILE LOAD=plr
```

This restores the mesh that was saved during the original print preparation.

---

### 8. Return to the recovery height

KlipperPLR commands:

```gcode
G90
G1 Z<saved_z> F300
```

The printer is now logically and physically positioned at the saved layer height.

---

### 9. Resume the original G-code

The generated recovery file contains the original G-code beginning at the matching recovery layer.

Klipper starts this file through the virtual SD card and continues the print.

---

# Recovery messages

During recovery, messages similar to the following may appear in the Klipper console:

```text
PLR: Recovery bei Layer Z=0.8
PLR: Home X/Y
PLR: X/Y Homing abgeschlossen
PLR: Lade gespeichertes Bed Mesh
PLR: Bed Mesh geladen
PLR: Fahre auf Z=0.8
PLR: Recovery-Position erreicht
```

These messages can help identify the current stage of the recovery process.

---

# Manual recovery parameters

For troubleshooting or controlled testing, a recovery height can be supplied manually:

```gcode
RESUME_INTERRUPTED Z_HEIGHT=0.8
```

KlipperPLR normally obtains this value from:

```text
power_resume_z
```

The recovery macro also supports an explicit G-code filename through:

```text
GCODE_FILE
```

Manual parameters are intended primarily for testing and troubleshooting.

For a normal power-loss event, use:

```gcode
RESUME_INTERRUPTED
```

---

# Controlled recovery test

Before relying on KlipperPLR for long prints, perform a controlled test.

Use a small, simple test object.

## Test procedure

1. Slice the object with:

```gcode
LOG_Z Z={layer_z}
```

configured in OrcaSlicer.

2. Start the print normally.

3. Allow several layers to print.

4. Verify that Klipper reports messages such as:

```text
PLR: Layer Z=<value> gespeichert
```

5. Simulate the interruption.

6. Do not physically move the Z axis.

7. Restore power and wait for Klipper to reconnect.

8. Visually inspect the printer.

9. Execute:

```gcode
RESUME_INTERRUPTED
```

10. Observe the entire recovery process.

Be prepared to stop the printer immediately if the toolhead moves in an unexpected direction.

---

# When recovery should NOT be used

Do not attempt recovery if:

- the print detached from the bed
- the Z axis moved while power was off
- the bed or gantry moved vertically
- the printer lost its mechanical Z reference
- X/Y homing would collide with the printed object
- the stored recovery data belongs to another print
- the original G-code file no longer exists
- the printer configuration changed after the interruption
- the saved bed mesh is no longer valid
- the printer experienced a mechanical failure

In these situations, starting the print again is safer than attempting recovery.

---

# Clearing recovery data

Generated recovery files can be removed with:

```gcode
G31
```

The stored print information can be cleared with:

```gcode
clear_last_file
```

After a successfully completed print, the saved print information should normally be cleared.

---

# Recovery files

Generated files are stored under:

```text
~/printer_data/gcodes/plr/
```

The original G-code is not modified.

KlipperPLR creates a separate recovery version of the file.

This makes it possible to inspect the generated G-code without changing the original sliced file.

---

# Important limitations

KlipperPLR reconstructs the print state from information available in the original G-code and the saved recovery variables.

Not every possible printer state can be reconstructed.

Printer-specific macros, external hardware, multi-material systems, tool changers, object exclusion states, or unusual custom G-code may require additional handling.

A successful recovery therefore cannot be guaranteed for every printer or every sliced file.

Always test the recovery process on your specific printer configuration before relying on it.