# Zapuskalka

Zapuskalka is a cross-platform launcher and distribution platform for indie games and
applications.

[![Download the latest release](https://img.shields.io/github/v/release/rodd-oss/zapuskalka?display_name=release&label=Download&style=for-the-badge)](https://github.com/rodd-oss/zapuskalka/releases/latest)

## Download

Download the current launcher from [GitHub Releases](https://github.com/rodd-oss/zapuskalka/releases/latest):

- **Windows:** `.exe` or `.msi`
- **macOS:** `.dmg` for Apple Silicon or Intel
- **Linux:** `.AppImage`, `.deb`, or `.rpm`

The launcher checks for signed updates through this repository. Do not download installers
from third-party mirrors.

## Support

Use [Issues](https://github.com/rodd-oss/zapuskalka/issues) for user-facing bugs. Include the
launcher version, operating system version, reproduction steps, and logs where possible.

Do not report security vulnerabilities in public issues. Follow
[SECURITY.md](SECURITY.md) instead.

## Source code and licensing

This repository is the public distribution point for Zapuskalka. Product source code is not
stored on the `main` branch.

Each release provides the corresponding MPL-licensed launcher source as a separate
`zapuskalka-launcher-source-<version>.tar.gz` asset. See [LICENSES.md](LICENSES.md) for details.

The pre-Rust legacy project is preserved in the archived
[zapuskalka-archive](https://github.com/rodd-oss/zapuskalka-archive) repository.
