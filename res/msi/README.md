# RustDesk msi project

## Sinaptic Remoto (instalador MSI)

El workflow `.github/workflows/sinaptic-build.yml` genera `SinapticRemoto-<versión>-x86_64.msi`
con este proyecto, como el workflow oficial, con estos datos:

| Dato | Valor |
| ---- | ----- |
| Nombre visible (`--display-name`, ProductName) | `Sinaptic Remoto` |
| Nombre interno (`--app-name`): carpeta, servicio, ejecutable | `SinapticRemoto` → `C:\Program Files\SinapticRemoto\SinapticRemoto.exe`, servicio `SinapticRemoto` |
| Fabricante (`-m`) | `Sinaptic` |
| Ícono | `res/icon.ico` (monitor con cursor, lo genera `res/generar_iconos_sinaptic.py`) |
| **UpgradeCode (`--upgrade-code`)** | **`278B8821-BA28-449A-89A9-DAAB79021808`** |
| Versión del MSI | `SINAPTIC_VERSION` con punto: `1.5.0-6` → `1.5.0.6` |

**El UpgradeCode NO se cambia nunca.** Se generó una vez (12/10/2026) y es lo que hace que
cada MSI nuevo reconozca al anterior y lo reemplace: `MajorUpgrade` con
`AllowSameVersionUpgrades="yes"` y `Schedule="afterInstallInitialize"` desinstala la versión
vieja y pone la nueva. Windows Installer solo compara los tres primeros números
(1.5.0.6 y 1.5.0.7 cuentan como «la misma versión»), por eso hace falta
`AllowSameVersionUpgrades`; el ProductCode cambia en cada compilación.

Para actualizar un equipo basta con ejecutar el MSI nuevo encima (doble clic o
`msiexec /i SinapticRemoto-<versión>-x86_64.msi /qn`). Si el equipo tiene Sinaptic Remoto
instalado con el `.exe` autoinstalable, el MSI se niega («instalado por autoinstalación»):
hay que desinstalar antes esa copia.

Use Visual Studio 2022 to compile this project.

This project is mainly derived from <https://github.com/MediaPortal/MediaPortal-2.git> .

## Steps

1. `python preprocess.py`, see `python preprocess.py -h` for help.
2. Build the .sln solution.

Run `msiexec /i package.msi /l*v install.log` to record the log.

## Usage

1. Put the custom dialog bitmaps in "Resources" directory. The supported bitmaps are `['WixUIBannerBmp', 'WixUIDialogBmp', 'WixUIExclamationIco', 'WixUIInfoIco', 'WixUINewIco', 'WixUIUpIco']`.

## Knowledge

### properties

[wix-toolset-set-custom-action-run-only-on-uninstall](https://www.advancedinstaller.com/versus/wix-toolset/wix-toolset-set-custom-action-run-only-on-uninstall.html)

| Property Name | Install | Uninstall | Change | Repair | Upgrade |
| ------ | ------ | ------ | ------ | ------ | ------ |
| Installed | False | True | True | True | True |
| REINSTALL | False | False | False | True | False |
| UPGRADINGPRODUCTCODE | False | False | False | False | True |
| REMOVE | False | True | False | False | True |

## TODOs

1. Start menu. Uninstall
1. custom options
1. Custom client.
    1. firewall and tcp allow. Outgoing
    1. Show license ?
    1. Do create service. Outgoing.

## Refs

1. [windows-installer-portal](https://learn.microsoft.com/en-us/windows/win32/Msi/windows-installer-portal)
1. [wxs](https://wixtoolset.org/docs/schema/wxs/)
1. [wxs github](https://github.com/wixtoolset/wix)
