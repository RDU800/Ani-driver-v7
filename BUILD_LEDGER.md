# Ani-Driver Build & Emulator Ledger

Tracks every green build, applied patch set, upstream base revision, and emulator performance delta.

## 1. Builds

| Date (UTC) | Build / Tag | Commit | Run / Artifact | Upstream Base | Patches Added | Perf vs Prev |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-11-21 | `ani-panvk-bifrost` | `ec64b67` | Run `44911242549` / `14709963437` | Mesa `6a5343b` | `none` (baseline) | Baseline |

## 2. Patch List

| ID | Patch File | Type | What It Changes |
| :--- | :--- | :--- | :--- |
| `0001` | `0001-Four-Vulkan-1.3-extensions...patch` | `malisx2` | Adds Vulkan 1.3 extensions & texel buffer alignment properties |
| `0100` | `0100-ani-custom.patch` | `ani-driver` | Your custom change or batching test |

## 3. Emulator Results

| Build | Emulator | Game / Scene | Cap / Settings | FPS (Min/Avg/Max) | Perf Change | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ani-panvk-bifrost` | *Emulator* | *Game / scene* | *FPS cap / preset* | *0 / 0 / 0* | `= Same` | Baseline run |
