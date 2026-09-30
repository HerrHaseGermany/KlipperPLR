# Klipper Configuration

KlipperPLR integrates with Klipper through the generated `plr.cfg` configuration file.

The installer automatically creates this file and adds it to `printer.cfg`.

Normally, `plr.cfg` should not need to be edited manually.

---

## Required Klipper configuration

KlipperPLR requires the following Klipper components:

- Virtual SD card
- Save Variables
- Respond
- G-code shell commands

The `respond` and shell-command configuration required by KlipperPLR is installed automatically.

The existing Klipper installation must provide the virtual SD card and save-variable configuration.

---

## Virtual SD Card

KlipperPLR works with G-code files printed through Klipper's virtual SD card.

A typical configuration is:

```ini
[virtual_sdcard]
path: ~/printer_data/gcodes
```

The exact path may differ depending on the Klipper installation.

KlipperPLR obtains the current file path from:

```text
printer.virtual_sdcard.file_path
```

This allows `save_last_file` to store the original G-code file used for recovery.

---

## Save Variables

KlipperPLR uses Klipper's persistent variable storage.

A typical configuration is:

```ini
[save_variables]
filename: ~/printer_data/config/save_variables.cfg
```

KlipperPLR stores three important values:

```text
last_file
filepath
power_resume_z
```

### `last_file`

Contains the filename of the active print.

Example:

```text
part_PETG.gcode
```

### `filepath`

Contains the path to the original G-code file.

This is used by the recovery script to locate and analyze the interrupted print.

### `power_resume_z`

Contains the last layer height reported by the slicer.

Example:

```text
0.8
```

This value is the central reference used to determine the recovery layer.

---

# KlipperPLR macros

The installer creates several G-code macros.

## `save_last_file`

Stores the current virtual SD card print file.

```gcode
save_last_file
```

This command should be executed when a normal print starts.

It stores:

```text
last_file
filepath
```

The macro obtains this information directly from Klipper's virtual SD card.

---

## `LOG_Z`

Stores the current slicer layer height.

Syntax:

```gcode
LOG_Z Z=<layer height>
```

Example:

```gcode
LOG_Z Z=0.8
```

Normally this command is not entered manually.

OrcaSlicer inserts it automatically before every layer change using:

```gcode
LOG_Z Z={layer_z}
```

KlipperPLR deliberately uses the layer height supplied by the slicer instead of reading the current physical toolhead Z coordinate.

This prevents temporary movements such as Z-hop from being stored as the recovery layer.

`LOG_Z` only updates the recovery value while Klipper reports the printer state as:

```text
printing
```

---

## `RESUME_INTERRUPTED`

Starts the recovery process.

Normal usage:

```gcode
RESUME_INTERRUPTED
```

KlipperPLR then uses the saved:

```text
power_resume_z
last_file
```

values automatically.

### Manual parameters

The macro also accepts explicit recovery information.

Example:

```gcode
RESUME_INTERRUPTED Z_HEIGHT=0.8
```

The macro supports:

```text
Z_HEIGHT
GCODE_FILE
```

When parameters are not supplied, the saved values are used.

For normal power-loss recovery, manual parameters should not be necessary.

---

## `clear_last_file`

Clears the stored information for the completed print:

```gcode
clear_last_file
```

It resets:

```text
last_file
filepath
power_resume_z
```

This should normally be executed after a print has completed successfully.

---

## `G31`

Deletes generated Power Loss Recovery files:

```gcode
G31
```

The command executes the KlipperPLR cleanup script.

It does not remove the original G-code file.

---

# Recovery coordinate handling

After a restart, Klipper no longer knows the physical position of the printer.

KlipperPLR restores the saved Z coordinate with:

```gcode
SET_KINEMATIC_POSITION Z=<saved_z> SET_HOMED=Z CLEAR_HOMED=XY
```

This is an important part of the recovery mechanism.

It tells Klipper:

```text
Z   = known
X   = unhomed
Y   = unhomed
```

KlipperPLR can then execute:

```gcode
G28 X Y
```

without physically homing Z.

This preserves the physical Z position of the interrupted print.

---

# Homing requirements

The printer must support safe X/Y homing while the print remains on the bed.

During recovery KlipperPLR executes:

```gcode
G28 X Y
```

The printer configuration must therefore allow X and Y to home without requiring Z to be homed again.

Custom `homing_override` configurations should be checked carefully.

A homing override that automatically homes Z when `G28 X Y` is requested can make recovery unsafe.

---

# Bed Mesh

KlipperPLR currently restores the mesh profile:

```text
plr
```

during recovery using:

```gcode
BED_MESH_PROFILE LOAD=plr
```

The normal print preparation therefore needs to save the mesh under this name.

Example:

```gcode
BED_MESH_CLEAR
BED_MESH_CALIBRATE ADAPTIVE=1 ADAPTIVE_MARGIN=5
BED_MESH_PROFILE SAVE=plr
```

KlipperPLR can therefore also be used with Klipper's adaptive bed mesh functionality.

The exact mesh configuration remains printer-specific.

---

# Temperature recovery

The recovery script analyzes the original G-code before the recovery layer.

It searches for the most recent bed-temperature commands:

```gcode
M140
M190
```

and hotend-temperature commands:

```gcode
M104
M109
```

The detected temperatures are inserted into the generated recovery G-code.

This allows the bed and hotend to return to their previous printing temperatures before the print continues.

---

# Extrusion mode recovery

KlipperPLR determines whether the original G-code uses relative extrusion:

```gcode
M83
```

or absolute extrusion.

For relative extrusion, the recovery G-code resets the extruder coordinate and restores:

```gcode
M83
```

For absolute extrusion, KlipperPLR determines the last extrusion coordinate before the recovery layer and restores it using:

```gcode
G92 E<value>
```

---

# Recovery G-code

Recovery files are generated in:

```text
~/printer_data/gcodes/plr/
```

The generated file contains the recovery preparation followed by the remaining part of the original print.

KlipperPLR searches the original G-code for the matching combination:

```gcode
;LAYER_CHANGE
;Z:<saved layer height>
```

The remaining print is copied starting at that layer.

---

# Legacy `LOG_Z` handling

When generating a recovery file, KlipperPLR also checks the remaining original G-code for old parameterless commands:

```gcode
LOG_Z
```

If the corresponding layer height can be determined, these commands are converted to:

```gcode
LOG_Z Z=<layer height>
```

This prevents a recovered print from failing when older sliced files are used.

The generated recovery file is checked before it is accepted.

If parameterless `LOG_Z` commands remain, generation is aborted.

---

# Printer-specific configuration

KlipperPLR intentionally does not configure printer hardware.

The following remain part of the user's normal Klipper configuration:

```text
Stepper configuration
Endstops
Probe
Z offset
Homing
Bed dimensions
Bed mesh dimensions
Heaters
Fans
Toolhead
```

KlipperPLR only handles the information necessary to reconstruct and resume the interrupted print.

---

# Important limitation

The saved Z coordinate is a logical coordinate.

KlipperPLR assumes that the physical Z position has not changed since the power loss.

If the gantry, bed, Z screws, or toolhead move while the printer is powered off, the stored coordinate may no longer correspond to the physical printer position.

In that situation the interrupted print should not be resumed.

---

# Next step

Configure the slicer so every layer reports its intended Z height.

See:

```text
docs/ORCA-SLICER.md
```