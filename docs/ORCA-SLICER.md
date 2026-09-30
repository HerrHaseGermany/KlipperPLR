# OrcaSlicer Configuration

KlipperPLR requires the slicer to report the intended Z height of every printed layer.

The following configuration describes the setup for OrcaSlicer.

---

## Before Layer Change G-code

Open your printer profile in OrcaSlicer and navigate to:

**Printer Settings → Machine G-code → Before layer change G-code**

Add:

```gcode
LOG_Z Z={layer_z}
```

If you already have commands in this field, add `LOG_Z` without removing the existing commands.

For example:

```gcode
LOG_Z Z={layer_z}
```

OrcaSlicer replaces `{layer_z}` with the Z height of the corresponding layer.

The resulting G-code will contain entries similar to:

```gcode
;LAYER_CHANGE
;Z:0.2
LOG_Z Z=0.2
```

and later:

```gcode
;LAYER_CHANGE
;Z:0.8
LOG_Z Z=0.8
```

KlipperPLR uses these values to identify the correct recovery layer.

---

## Why the slicer provides the Z height

KlipperPLR intentionally does not use the current physical toolhead position as the recovery layer.

During a print, the toolhead may temporarily move in Z because of features such as:

```text
Z-hop
Travel moves
Custom macros
Toolhead parking
```

The physical Z coordinate at a particular moment may therefore differ from the actual layer being printed.

OrcaSlicer already knows the intended layer height.

Using:

```gcode
LOG_Z Z={layer_z}
```

therefore provides KlipperPLR with the logical layer height directly.

---

## Save the print file

KlipperPLR also needs to know which G-code file is currently being printed.

The following macro must be executed at the beginning of a normal print:

```gcode
save_last_file
```

Add it to your normal print start sequence before the actual printing begins.

For example:

```gcode
save_last_file
PRINT_START
```

The exact position may depend on your existing start G-code and Klipper macros.

`save_last_file` reads the current file from Klipper's virtual SD card and stores it for recovery.

---

## Bed Mesh

KlipperPLR currently expects the recovery mesh to be stored as:

```text
plr
```

If a bed mesh is generated at the start of every print, save it after calibration:

```gcode
BED_MESH_CLEAR
BED_MESH_CALIBRATE ADAPTIVE=1 ADAPTIVE_MARGIN=5
BED_MESH_PROFILE SAVE=plr
```

During recovery KlipperPLR loads it with:

```gcode
BED_MESH_PROFILE LOAD=plr
```

If your printer uses a different bed-mesh workflow, make sure a valid profile named `plr` exists before relying on recovery.

---

## Example start sequence

A simplified print-start sequence could look like:

```gcode
save_last_file

M140 S[hot_plate_temp_initial_layer]

G28

M109 S[nozzle_temperature_initial_layer]

M190 S[hot_plate_temp_initial_layer]

BED_MESH_CLEAR
BED_MESH_CALIBRATE ADAPTIVE=1 ADAPTIVE_MARGIN=5
BED_MESH_PROFILE SAVE=plr

PRINT_START
```

This is only an example.

Do not blindly replace an existing start sequence with this example. Heating, homing, wiping, probing and purge-line procedures are printer-specific.

The two KlipperPLR-related requirements are:

```gcode
save_last_file
```

and a saved mesh profile named:

```text
plr
```

---

## Successful print cleanup

After a print finishes successfully, the stored recovery information should be cleared.

KlipperPLR provides:

```gcode
clear_last_file
```

This can be added to the normal end-of-print sequence.

Example:

```gcode
PRINT_END
clear_last_file
```

The exact placement depends on the existing printer configuration.

`clear_last_file` resets:

```text
last_file
filepath
power_resume_z
```

This prevents an old successfully completed print from remaining registered as the current recovery job.

---

## Verify the generated G-code

Before testing power-loss recovery, slice a small test object.

Open the generated `.gcode` file and search for:

```text
LOG_Z
```

You should see commands such as:

```gcode
;LAYER_CHANGE
;Z:0.2
LOG_Z Z=0.2
```

followed by subsequent layers:

```gcode
;LAYER_CHANGE
;Z:0.4
LOG_Z Z=0.4

;LAYER_CHANGE
;Z:0.6
LOG_Z Z=0.6

;LAYER_CHANGE
;Z:0.8
LOG_Z Z=0.8
```

There should not be parameterless commands such as:

```gcode
LOG_Z
```

for newly sliced files.

---

## Verify during a print

During a normal print, Klipper should report messages similar to:

```text
PLR: Layer Z=0.8 gespeichert
```

The value should follow the current layer height.

This confirms that OrcaSlicer is supplying the layer height and KlipperPLR is storing it.

---

## Important

Do not use:

```gcode
LOG_Z
```

without the `Z` parameter.

The current implementation requires:

```gcode
LOG_Z Z=<layer height>
```

For OrcaSlicer, always use:

```gcode
LOG_Z Z={layer_z}
```

---

## Next step

After OrcaSlicer and KlipperPLR have been configured, perform a controlled recovery test before relying on the system for long prints.

See:

```text
docs/RECOVERY.md
```