# chd-extractor

Bulk-extract CHD disc images (CD-ROM, GD-ROM, and DVD-ROM) using [chdman](https://docs.mamedev.org/tools/chdman.html), the disc image manager from the MAME project.

## Requirements

- A `chdman` binary in the same folder as `extract_chds.sh` (not included in this repo — download it from a [MAME release](https://www.mamedev.org/release.html) matching your platform).
- bash

## Usage

```sh
./extract_chds.sh -i <input_folder> -o <output_folder> [--extension .cue|.gdi|.iso]
```

- `-i`, `--input` — folder containing `.chd` files (files directly inside this folder are processed; subfolders are not searched).
- `-o`, `--output` — folder to write extracted disc images into (created if it doesn't exist).
- `--extension` — force one output format for every file instead of auto-detecting.

Already-extracted discs (an existing output file with the expected name) are skipped, so a batch can safely be re-run to resume after an interruption.

### Output layout

- **DVD-ROM** (PS2, etc.) → a single `<output_folder>/<name>.iso` file.
- **CD-ROM** → `<output_folder>/<name>/<name>.cue` + `<name>.bin`.
- **GD-ROM** (Dreamcast) → `<output_folder>/<name>/<name>.gdi` + track files.

CUE/BIN and GDI get their own subfolder per disc since they're made of multiple files; ISO doesn't need one since it's already a single file.

## Disc type detection

By default, each CHD's disc type is auto-detected via `chdman info`, by reading its metadata tag — no need to rely on filename conventions:

| Metadata tag | Disc type | Extraction command | Output |
|---|---|---|---|
| `DVD ` | DVD-ROM | `chdman extractdvd` | `.iso` |
| `CHGD` | GD-ROM (Dreamcast) | `chdman extractcd` | `.gdi` |
| anything else | CD-ROM | `chdman extractcd` | `.cue` + `.bin` |

### Why GD-ROM needs GDI, not CUE/BIN

Dreamcast GD-ROM discs have a large gap between their two sessions. GDI represents that gap structurally in its track table. CUE/BIN has no equivalent, so forcing a GD-ROM CHD into that format makes chdman write the gap out as literal data — and at least in chdman 0.289, this triggers a runaway write loop that never terminates on its own, consuming disk space indefinitely instead of stopping at the disc's actual size. Extracting to `.gdi` avoids the bug entirely and is also the Dreamcast-native format.

## Example

```sh
./extract_chds.sh -i ~/roms/PS2/Discs -o ~/roms/PS2/Discs/output
```
