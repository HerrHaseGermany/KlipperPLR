# Installation

This guide describes how to install KlipperPLR on an existing Klipper system.

## Requirements

KlipperPLR expects a standard Klipper installation with the following directory structure:

```text
~/klipper/
~/printer_data/
└── config/
    ├── printer.cfg
    └── moonraker.conf
```

The installation must provide:

- Klipper
- Moonraker
- a configured virtual SD card
- `save_variables`
- Git
- Bash
- Python 3

KlipperPLR has primarily been developed and tested with Mainsail and OrcaSlicer.

---

## 1. Clone KlipperPLR

Connect to the Klipper host using SSH and clone the repository into the home directory:

```bash
cd ~
git clone https://github.com/HerrHaseGermany/KlipperPLR.git
cd KlipperPLR
```

The repository may technically be located elsewhere. The installer automatically detects the repository location and writes the correct absolute paths into the generated Klipper configuration.

---

## 2. Run the installer

Make the installer executable:

```bash
chmod +x install.sh
```

Run it:

```bash
./install.sh
```

Normally, the installer should be executed as the same user that runs Klipper.

The installer can also determine the original user when invoked through `sudo`.

---

## What the installer does

The installer automatically detects:

```text
User home directory
Klipper directory
printer_data directory
KlipperPLR repository directory
```

For a typical installation this may look like:

```text
/home/biqu/KlipperPLR
/home/biqu/klipper
/home/biqu/printer_data/config
```

No username is hard-coded by the installer.

---

## gcode_shell_command

KlipperPLR requires the Klipper extension:

```text
gcode_shell_command.py
```

The installer creates a symbolic link from:

```text
KlipperPLR/gcode_shell_command.py
```

to:

```text
~/klipper/klippy/extras/gcode_shell_command.py
```

If a regular `gcode_shell_command.py` already exists at the destination, the installer creates a backup:

```text
gcode_shell_command.py.backup
```

before installing the KlipperPLR version.

If the destination already contains a symbolic link, that link is replaced.

---

## Klipper configuration

The installer generates:

```text
~/printer_data/config/plr.cfg
```

This file contains the KlipperPLR macros and shell-command definitions.

The installer then adds:

```ini
[include plr.cfg]
```

to `printer.cfg` if it is not already present.

The include is added automatically and is not duplicated when the installer is run again.

---

## Moonraker Update Manager

If:

```text
~/printer_data/config/moonraker.conf
```

exists, the installer creates:

```text
~/printer_data/config/update_plr.cfg
```

with a Moonraker Update Manager configuration for KlipperPLR.

It also adds:

```ini
[include update_plr.cfg]
```

to `moonraker.conf`.

The generated Update Manager configuration uses:

```ini
[update_manager KlipperPLR]
type: git_repo
path: <KlipperPLR repository path>
origin: https://github.com/HerrHaseGermany/KlipperPLR.git
primary_branch: main
install_script: install.sh
is_system_service: False
```

After installation, KlipperPLR should therefore appear in the Moonraker/Mainsail Update Manager.

---

## Restart Klipper and Moonraker

After installation, restart both Klipper and Moonraker.

This is required because Klipper must load:

```text
gcode_shell_command.py
```

and the newly generated:

```text
plr.cfg
```

Moonraker must also reload its Update Manager configuration.

You can restart the services through Mainsail or using the appropriate service commands for your system.

---

## Verify the installation

After restarting, verify that Klipper starts without configuration errors.

The following KlipperPLR commands should now exist:

```text
save_last_file
clear_last_file
LOG_Z
RESUME_INTERRUPTED
G31
```

The Mainsail Update Manager should also contain:

```text
KlipperPLR
```

---

## Required save_variables configuration

KlipperPLR stores recovery information using Klipper's `save_variables` functionality.

Your Klipper configuration therefore needs a `[save_variables]` section.

Example:

```ini
[save_variables]
filename: ~/printer_data/config/save_variables.cfg
```

Do not manually edit `save_variables.cfg` while Klipper is running.

KlipperPLR uses it to store values including:

```text
last_file
filepath
power_resume_z
```

---

## Recovery directory

Recovery G-code files are generated in:

```text
~/printer_data/gcodes/plr/
```

The directory is created automatically when required.

It does not need to exist before installation.

---

## Next step

After installation, the slicer must be configured to provide the layer height to KlipperPLR.

See:

```text
docs/ORCA-SLICER.md
```

The most important slicer command is:

```gcode
LOG_Z Z={layer_z}
```

Without this command, KlipperPLR cannot reliably determine the layer from which the print should be recovered.

---

## Updating

Once KlipperPLR is registered with the Moonraker Update Manager, future updates can be installed through Mainsail.

Alternatively, the repository can be updated manually:

```bash
cd ~/KlipperPLR
git pull
```

If an update changes installation-related files or generated configuration, run:

```bash
./install.sh
```

again and restart Klipper and Moonraker.

---

## Uninstallation

To remove KlipperPLR:

```bash
cd ~/KlipperPLR
./uninstall.sh
```

See the project documentation for additional information about configuration cleanup and recovery files.

---

## Important safety note

Power-loss recovery restores a previously known Z coordinate without physically homing the Z axis.

The printer must therefore not lose its physical Z position while powered off.

Do not manually move the Z axis or gantry after a power loss if you intend to recover the interrupted print.

Always test KlipperPLR with a non-critical print before relying on it for long prints.