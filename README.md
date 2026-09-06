# chd-extractor

Bulk-extract CHD disc images (CD-ROM, GD-ROM, and DVD-ROM) using [chdman](https://docs.mamedev.org/tools/chdman.html), the disc image manager from the MAME project.

## Requirements

- A `chdman` binary (not included in this repo — download it from a [MAME release](https://www.mamedev.org/release.html) matching your platform), either next to `chd-extractor.sh` or available on your `PATH`.

## Usage

```sh
./chd-extractor.sh -i <input_folder> [-o <output_folder>] [--extension .cue|.gdi|.iso]
```

- `-i`, `--input` — folder containing `.chd` files (files directly inside this folder are processed; subfolders are not searched).
- `-o`, `--output` — folder to write extracted disc images into (created if it doesn't exist). Defaults to an `output` subfolder inside `<input_folder>` if omitted.
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

## Example

```sh
./chd-extractor.sh -i ~/roms/PS2
```

Extracts everything into `~/roms/PS2/output`.
