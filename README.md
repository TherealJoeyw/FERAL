# FERAL

(<img width="1455" height="510" alt="FERAl banner" src="https://github.com/user-attachments/assets/efd91965-73c1-406c-8334-d2345f7b50fe" />)

FERAL is an offline-first field computing platform built from low-cost hardware where each component operates independently and synchronizes opportunistically when links exist. It is designed for degraded conditions where networks fail and infrastructure cannot be trusted, with a form factor that blends into normal handheld electronics while still providing practical reconnaissance and analysis capability.

## Components

| Component | Expansion | Role |
|---|---|---|
| PAW | Peripheral Auxiliary Workstation | Operator handheld interface, local apps, and field control surface |
| WHISKER | Wireless Hub for Intelligence, Sensing, Kinetics, and Environmental Reconnaissance | Sensing and communications hub with continuous logging |
| STALK | Synchronised Telemetery Analysis and Logging Kernel | Home/backend sync, storage, local AI, and update distribution |
| SCAR | Standard Calico Asset Receptacle | Open USB-C based module standard for hardware expansion |

## Hardware

- **PAW reference hardware:** Anbernic RG35XX H (Allwinner H700 handheld)
- **WHISKER reference hardware:** Raspberry Pi Zero 1W/2W with custom carrier

## Licensing

This repository uses a split licence model:

- `paw/`, `whisker/`, `stalk/`, and `scar/` source code is licensed under **PolyForm Noncommercial 1.0**.
- `feral-os/` and `tools/` build configuration and infrastructure glue are licensed under **MIT**.

See `LICENCE-polyform-nc` and `LICENCE-mit` in the repository root.

## Current status

- Architecture specification is complete.
- Reference hardware has been validated (RG35XX H boot, WiFi, and Bluetooth confirmed).
- Application code, Buildroot images, and SCAR module implementations are not yet present.

## Contributing

Contribution guidelines will be added as implementation begins. For now, open issues or design discussions before submitting major structural changes.
