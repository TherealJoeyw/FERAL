# CALICO FERAL

**Field Expedient Reconnaissance and Analysis Laboratory**

FERAL is an open source modular field computing platform built around a single design principle: *structural privacy*. Not a locked door. Not a hardened system. An architecture that is physically and logically incapable of surveillance by design.

The difference matters. A locked door can be unlocked. A system with no server to report to, no persistent keys to seize, and no network to intercept has nothing to give up. Privacy here is a property of the structure, not a policy applied on top of it. The closest analogies are Tor and Bitcoin — systems where the guarantee comes from how they work, not from promises made by the people who run them.

FERAL is also a practical tool. It runs on cheap, widely available hardware. It works offline. It syncs opportunistically when links exist and degrades gracefully when they don't. The goal is a field computing capability that fits in a jacket pocket and blends into everyday electronics while providing real utility in degraded or hostile environments.

It is a political statement that also works.

---

## Components

FERAL is modular. Each component is an independent platform that runs FERAL OS and operates standalone. They coordinate when they can and continue working when they can't.

| Component | Full name | Role |
|-----------|-----------|------|
| **PAW** | Peripheral Auxiliary Workstation | Primary operator interface. Handheld form factor. Local apps, field control, and user interaction. |
| **WHISKER** | Wireless Hub for Intelligence, Sensing, Kinetics, and Environmental Reconnaissance | Sensor and communications node. Continuous logging. Runs headless. |
| **STALK** | System for Thinking, Analysis, Learning and Knowledge | Home backend. Inference, storage, sync distribution, and update serving. Runs in Docker. |
| **CLAW** | (bare metal/RTOS firmware nodes) | ESP32-based peripheral and mesh nodes. Bare metal or FreeRTOS. Not a FERAL OS profile. |
| **SCAR** | Standard Calico Asset Receptacle | Open USB-C hardware expansion standard. Shared across PAW and WHISKER. |

PAW, WHISKER, and STALK all run FERAL OS. CLAW runs independently and communicates with the rest of the platform over serial or mesh protocols. SCAR is a hardware standard, not a device.

---

## FERAL OS

FERAL OS is a Buildroot-based Linux system. It is hardware-agnostic and profile-detected at boot. The same image tree targets PAW (Allwinner H700), WHISKER (Raspberry Pi Zero 2W), and STALK (x86/ARM64 container host) through profile selection at build time.

It is offline-first. Sync is opportunistic over any available IP link. MeshCore LoRa is reserved for low-bandwidth beacons and status, not bulk transfer.

---

## Reference hardware

| Component | Hardware |
|-----------|----------|
| PAW | Anbernic RG35XX H (Allwinner H700) — current reference hardware. PAW targets any compact handheld or cyberdeck-style device running a supported SoC. More platforms will be added as FERAL OS matures. |
| WHISKER | Raspberry Pi Zero 2W |
| STALK | Any x86 or ARM64 host running Docker |
| CLAW | ESP32 (various modules) |

---

## Repository structure

```
feral-os/       FERAL OS build system and overlays (MIT)
paw/            PAW application code and hardware config (PolyForm Noncommercial 1.0)
whisker/        WHISKER application code and hardware config (PolyForm Noncommercial 1.0)
stalk/          STALK container definitions and services (PolyForm Noncommercial 1.0)
scar/           SCAR hardware standard and module specs (PolyForm Noncommercial 1.0)
tools/          Build scripts and repo scaffolding (MIT)
docs/           Architecture, threat model, philosophy, and design documentation
devlogs/        Development logs
```

---

## Current status

PAW bring-up is in progress. U-Boot runs. The kernel boots. Networking is not yet functional.

WHISKER, STALK, and CLAW are in the architecture and specification phase.

This is early-stage hobby development. Nothing here is production ready.

---

## Licensing

This repository uses a split licence model.

`paw/`, `whisker/`, `stalk/`, and `scar/` are licensed under **PolyForm Noncommercial 1.0**. You can use, study, and modify them for non-commercial purposes. Commercial use requires a separate agreement.

`feral-os/` and `tools/` are licensed under **MIT**. Use them however you want.

Licence texts are in `LICENCE-polyform-nc` and `LICENCE-mit` in the repository root.

---

## Contributing

Architecture and design decisions are documented in `docs/`. Read those before opening a PR. For structural changes, open an issue first.

Contribution guidelines will be formalised as the codebase matures.

---
