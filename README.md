# ZapuskAlka (Gigabah Game Launcher)

Multiplatform (currently focused on Windows) game launcher for the Gigabah project, extracted to its own repository. It checks the latest GitHub Release of the target game repo and downloads / unpacks the first ZIP asset into a local `game/` folder, then launches the game executable.

## Key Features
- Fetches latest release metadata via GitHub REST API (`/repos/<owner>/<repo>/releases/latest`).
- Compares local version (stored in `game/version.json`) with release tag (SemVer, `vX.Y.Z` or `X.Y.Z`).
- Downloads first `.zip` asset from the release, extracts into `game/`.
- Provides basic UI (Godot) with status + launch button.
- Auto-closes after launching the game (configurable: remove `get_tree().quit()` to keep it open).

## Folder Structure
```
project.godot
scenes/Launcher.tscn
scripts/
  launcher.gd
  update_manager.gd
launcher_readme.md   <- Detailed Russian guide (deployment & operations)
README.md            <- This file (English overview)
.godot/              <- Godot internal (ignored)
launcher_tmp/        <- Temp download dir (ignored)
```
A `game/` folder is created at runtime after the first successful download.

## Configuration
Edit constants in `scripts/update_manager.gd`:
- `GITHUB_OWNER` – repository owner
- `GITHUB_REPO` – repository name
Tags must follow SemVer (`0.1.0` or `v0.1.0`). The leading `v` is stripped automatically.

## Release / Update Flow
1. Export a full build of the game (outside this launcher repo).
2. Zip the contents (no extra top-level directory) e.g. `gigabah_0.1.0.zip`.
3. Create / publish a GitHub Release with tag `v0.1.0` (or `0.1.0`) and attach the ZIP as the FIRST asset.
4. Start launcher: it downloads and unpacks to `game/`, writes `game/version.json`.
5. For an update: repeat with `0.1.1` etc.

## Build / Run (Godot)
Open `project.godot` in Godot (4.x). Run the main scene (`scenes/Launcher.tscn`) or configure it as the main scene in Project Settings.

## Roadmap Ideas
- Partial patch updates (delta ZIPs)
- Channel support (stable / beta / nightly by tag prefix filtering)
- File deletion / cleanup between versions
- SHA-256 verification (extra `.sha256` asset)
- Streaming progress bar & resume
- Local log file

## Contributing
Open issues / pull requests. Keep code style consistent with existing GDScript style; small focused commits preferred.

## License
Specify license here (MIT? Apache-2.0?). TODO: Decide and add LICENSE file.

## Additional Documentation (Russian)
See `launcher_readme.md` for an extended Russian operations handbook.
