# CALICO FERAL

Field Expedient Reconnaissance and Analysis Laboratory.

An open source modular offline-first field computing platform built from cheap consumer hardware.

## Components

| Name    | Description                                           | Hardware             |
|---------|-------------------------------------------------------|----------------------|
| PAW     | Field interface device                                | Any Linux handheld   |
| WHISKER | Sensor array                                          | Raspberry Pi Zero 2W |
| STALK   | Home backend (LLM inference, sync, storage)           | Docker host          |
| CLAW    | Fixed/disposable deployment node                      | ESP32                |
| SCAR    | Standard Calico Asset Receptacle (expansion standard) | USB-C hardware spec  |

## Repo structure

```
docs/           Documentation, devlogs, explainers
tools/          Build and scaffold scripts (MIT)
feral-os/       OS layer — Buildroot configs and rootfs overlays (MIT)
paw/            PAW component (PolyForm Noncommercial)
whisker/        WHISKER component (PolyForm Noncommercial)
stalk/          STALK backend (PolyForm Noncommercial)
claw/           CLAW firmware — not a FERAL OS profile (PolyForm Noncommercial)
scar/           SCAR standard (PolyForm Noncommercial)
```

## Licensing

`tools/` and `feral-os/` are MIT licensed.
Everything else is PolyForm Noncommercial 1.0.

## Status

Early development. PAW bringup in progress.

Repository: [github.com/TherealJoeyw/FERAL](https://github.com/TherealJoeyw/FERAL)
