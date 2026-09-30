# KlipperPLR

Power Loss Recovery for Klipper.

KlipperPLR adds a power-loss recovery mechanism to Klipper-based 3D printers. During a print, the current layer height and print file are stored. After an unexpected power loss or restart, KlipperPLR can generate a recovery G-code and continue the interrupted print.

> [!IMPORTANT]
> KlipperPLR is currently an experimental project. Power-loss recovery can never guarantee a successful print. Always verify the printer position and recovery data before resuming a print.

## Features

- Power-loss recovery for Klipper
- Stores the current print file automatically
- Stores the actual slicer layer height
- Reconstructs the Z position after a restart
- Re-homes X and Y without losing the recovered Z position
- Restores bed and hotend temperatures
- Restores the extrusion mode
- Restores a saved bed mesh
- Generates a dedicated recovery G-code
- Repairs legacy parameterless `LOG_Z` commands in the recovered G-code
- Moonraker Update Manager support
- Installer and uninstaller included

## Requirements

KlipperPLR requires:

- Klipper
- Moonraker
- a virtual SD card configuration
- `save_variables`
- `gcode_shell_command.py`
- a slicer capable of inserting custom layer-change G-code

The current implementation has been developed and tested with OrcaSlicer.

## Installation

Clone the repository into the home directory of the user running Klipper:

```bash
cd ~
git clone https://github.com/HerrHaseGermany/KlipperPLR.git
cd KlipperPLR
chmod +x install.sh
./install.sh
```

The installer configures the required Klipper integration and adds KlipperPLR to the Moonraker Update Manager.

Restart Klipper and Moonraker after installation if necessary.

## OrcaSlicer configuration

KlipperPLR needs the slicer to report the intended Z height of every layer.

In OrcaSlicer, add the following command to:

**Printer Settings → Machine G-code → Before layer change G-code**

```gcode
LOG_Z Z={layer_z}
```

This produces commands such as:

```gcode
;LAYER_CHANGE
;Z:0.8
LOG_Z Z=0.8
```

KlipperPLR stores this layer height for recovery.

## Starting a print

The current print file must be registered when the print starts.

Add:

```gcode
save_last_file
```

to your print start sequence before printing begins.

For example:

```gcode
save_last_file
```

The exact location depends on your existing Klipper and slicer configuration.

## Bed Mesh

KlipperPLR currently restores the bed mesh profile:

```text
plr
```

The mesh therefore needs to be saved during the normal print preparation:

```gcode
BED_MESH_PROFILE SAVE=plr
```

Adaptive bed meshes can also be used.

For example:

```gcode
BED_MESH_CLEAR
BED_MESH_CALIBRATE ADAPTIVE=1 ADAPTIVE_MARGIN=5
BED_MESH_PROFILE SAVE=plr
```

## Recovering an interrupted print

After an unexpected power loss, do **not manually move the Z axis**.

Once Klipper is running again, execute:

```gcode
RESUME_INTERRUPTED
```

KlipperPLR will:

1. Read the saved print file and layer height.
2. Generate a recovery G-code.
3. Restore the known Z coordinate.
4. Mark only Z as homed.
5. Home X and Y.
6. Restore the saved bed mesh.
7. Restore bed and hotend temperatures.
8. Restore the extrusion state.
9. Return to the saved layer height.
10. Continue the original G-code from the recovered layer.

The important Klipper command used during recovery is:

```gcode
SET_KINEMATIC_POSITION Z=<saved_z> SET_HOMED=Z CLEAR_HOMED=XY
```

This allows KlipperPLR to preserve the known Z position while X and Y are homed normally.

## Recovery files

Generated recovery files are stored in:

```text
~/printer_data/gcodes/plr/
```

The recovery file is generated from the original G-code when `RESUME_INTERRUPTED` is executed.

## Clearing recovery data

KlipperPLR provides:

```gcode
G31
```

to remove generated PLR recovery files.

The saved print information can be cleared using:

```gcode
clear_last_file
```

This should normally be called after a print has completed successfully.

## Update Manager

KlipperPLR supports the Moonraker Update Manager.

After installation it can be updated directly through interfaces such as Mainsail.

The repository used by the Update Manager is:

```text
https://github.com/HerrHaseGermany/KlipperPLR.git
```

## Uninstallation

Run:

```bash
cd ~/KlipperPLR
./uninstall.sh
```

The uninstaller removes the KlipperPLR integration while leaving unrelated Klipper configuration untouched.

## How it works

Klipper normally loses its trusted machine position after a restart. Simply continuing a G-code file is therefore not sufficient.

KlipperPLR solves this by storing the intended layer Z height during the print:

```gcode
LOG_Z Z={layer_z}
```

After a power loss, the saved Z coordinate is restored without physically homing Z:

```gcode
SET_KINEMATIC_POSITION Z=<saved_z> SET_HOMED=Z CLEAR_HOMED=XY
```

X and Y can then be homed normally.

KlipperPLR analyzes the original G-code, finds the corresponding:

```gcode
;LAYER_CHANGE
;Z:<saved_z>
```

marker and creates a new recovery G-code beginning at that layer.

## Safety

Power-loss recovery involves restoring printer coordinates without physically homing every axis.

Before using KlipperPLR:

- test the recovery process with a non-critical print
- make sure X and Y can home safely after a power loss
- make sure the Z axis does not move while the printer is powered off
- verify that your printer's homing configuration is compatible
- remain near the printer during recovery testing

Incorrect configuration can cause the toolhead to collide with the print, bed, or printer frame.

## Tested

The current recovery implementation has been tested with an actual power interruption and successfully resumed the interrupted print.

Development and initial testing were performed on a modified Artillery Sidewinder X4 Pro running Klipper on a BTT Manta M5P with a CB2 host.

Other printer configurations may require adjustments.

## Documentation

Detailed documentation is available in the `docs/` directory:

- [Installation](docs/INSTALLATION.md)
- [Klipper Configuration](docs/CONFIGURATION.md)
- [OrcaSlicer Configuration](docs/ORCA-SLICER.md)
- [Power Loss Recovery](docs/RECOVERY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License

See the `LICENSE` file for licensing information.

## Credits

KlipperPLR was originally based on the Power Loss Recovery implementation published by BIGTREETECH and has since been modified and extended.

Upstream project:

https://github.com/bigtreetech/KlipperPLR