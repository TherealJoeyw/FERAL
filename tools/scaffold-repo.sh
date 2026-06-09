#!/bin/bash
set -euo pipefail

# FERAL — repo scaffold script
# Run once after cloning an empty repo.
# Usage: bash tools/scaffold-repo.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "[FERAL] $*"; }

# ---------------------------------------------------------------------------
# Directory structure
# ---------------------------------------------------------------------------

DIRS=(
    docs
    tools
    feral-os/configs
    feral-os/overlays/paw
    feral-os/overlays/whisker
    paw
    whisker
    stalk
    claw
    scar
)

for d in "${DIRS[@]}"; do
    mkdir -p "$ROOT/$d"
    log "created $d/"
done

# ---------------------------------------------------------------------------
# License files
# ---------------------------------------------------------------------------

cat > "$ROOT/LICENSE-noncommercial" << 'EOF'
PolyForm Noncommercial License 1.0.0

<https://polyformproject.org/licenses/noncommercial/1.0.0>

Copyright (c) 2024 Zoey Wynne-Williams

Acceptance

In order to get any license under these terms, you must agree to them as
both strict obligations and conditions to all your licenses.

Copyright License

The licensor grants you a copyright license for the software to do
everything you might do with the software that would otherwise infringe
the licensor's copyright in it for any purpose other than commercial use.

No Commercial Use

You may not use the software for commercial purposes. Commercial use means
any use of the software for commercial advantage or private monetary
compensation, including use in a product or service you sell, use in
providing services to others for pay, and use in work you do for pay.

No Other Rights

These terms do not allow you to sublicense or transfer any of your licenses
to anyone else, or prevent the licensor from granting licenses to anyone else.

Patent License

The licensor grants you a patent license for the software that covers
patent claims the licensor can license, or will be able to license, that
you would infringe by using the software.

Fair Use

You may have "fair use" rights for the software under the law. These terms
do not limit them.

Termination

If you use the software in violation of these terms, such use is not
licensed, and your licenses will automatically terminate. If the licensor
provides you with a notice of your violation, and you cease all violation
of this license no later than 30 days after you receive that notice, your
licenses will be reinstated retroactively. However, if you violate these
terms after such reinstatement, any additional violation of these terms
will cause your licenses to terminate automatically and permanently.

No Liability

As far as the law allows, the software comes as is, without any warranty
or condition, and the licensor will not be liable to you for any damages
arising out of these terms or the use or nature of the software, under
any kind of legal claim.
EOF
log "created LICENSE-noncommercial"

cat > "$ROOT/LICENSE-mit" << 'EOF'
MIT License

Copyright (c) 2024 Zoey Wynne-Williams

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
log "created LICENSE-mit"

# ---------------------------------------------------------------------------
# Root files
# ---------------------------------------------------------------------------

cat > "$ROOT/.gitignore" << 'EOF'
# Build workspace
feral-build/

# Buildroot output
buildroot/

# Editor
.vscode/
*.swp
*~
EOF
log "created .gitignore"

cat > "$ROOT/README.md" << 'EOF'
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
EOF
log "created README.md"

# ---------------------------------------------------------------------------
# Component READMEs
# ---------------------------------------------------------------------------

write_readme() {
    local path="$ROOT/$1/README.md"
    [[ -f "$path" ]] && return
    cat > "$path"
    log "created $1/README.md"
}

write_readme docs << 'EOF'
# Docs

Project documentation, devlogs, and audience-specific explainers.
EOF

write_readme feral-os << 'EOF'
# FERAL OS

Buildroot-based Linux. Hardware profile detected at boot. Offline-first with opportunistic sync across any available IP network. MeshCore LoRa reserved for low-bandwidth status and beacons only.

Supported profiles: PAW, WHISKER, STALK.

Licensed under MIT — see `../LICENSE-mit`.
EOF

write_readme paw << 'EOF'
# PAW

Field interface device. Targets any Linux handheld. First supported hardware: Anbernic RG35XX H.

Runs FERAL OS in PAW profile.

Licensed under PolyForm Noncommercial 1.0 — see `../LICENSE-noncommercial`.
EOF

write_readme whisker << 'EOF'
# WHISKER

Sensor array. Raspberry Pi Zero 2W with custom PCB, 6x SCAR slots, 18650 batteries, and solar charging.

Runs FERAL OS in WHISKER profile.

Licensed under PolyForm Noncommercial 1.0 — see `../LICENSE-noncommercial`.
EOF

write_readme stalk << 'EOF'
# STALK

Docker-based home backend. Handles LLM inference (Ollama), sync, and storage.

Runs FERAL OS in STALK profile.

Licensed under PolyForm Noncommercial 1.0 — see `../LICENSE-noncommercial`.
EOF

write_readme claw << 'EOF'
# CLAW

ESP32 bare metal/RTOS firmware for fixed or disposable deployment nodes.

CLAW is not a FERAL OS profile. It is a separate firmware target.

Licensed under PolyForm Noncommercial 1.0 — see `../LICENSE-noncommercial`.
EOF

write_readme scar << 'EOF'
# SCAR

Standard Calico Asset Receptacle. Open USB-C hardware expansion standard shared across PAW and WHISKER. Wired and wireless variants.

Licensed under PolyForm Noncommercial 1.0 — see `../LICENSE-noncommercial`.
EOF

write_readme tools << 'EOF'
# Tools

Build and scaffold scripts.

- `build-paw-image.sh` — builds a FERAL OS PAW image for a given hardware profile
- `scaffold-repo.sh`   — creates the repo directory structure (this script)

Licensed under MIT — see `../LICENSE-mit`.
EOF

# ---------------------------------------------------------------------------
# STALK stub
# ---------------------------------------------------------------------------

if [[ ! -f "$ROOT/stalk/docker-compose.yml" ]]; then
    cat > "$ROOT/stalk/docker-compose.yml" << 'EOF'
# STALK — FERAL home backend
# TODO: define services (Ollama, sync agent, storage)
services: {}
EOF
    log "created stalk/docker-compose.yml"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

log ""
log "Scaffold complete."
log "Next: git init && git add . && git commit -m 'Initial scaffold'"
