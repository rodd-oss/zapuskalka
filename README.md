<div align="center">
  <img src="launcher-rust/app-icon.png" alt="Zapuskalka Logo" width="128" height="128">
  
  # Zapuskalka
  
  **Open-source launcher and platform for distributing indie games and applications**
  
  [![Latest Release](https://img.shields.io/github/v/release/rodd-oss/zapuskalka?label=Latest%20Release&style=for-the-badge)](https://github.com/rodd-oss/zapuskalka/releases/latest)
</div>

## About

Zapuskalka is a modern open-source launcher designed for indie game players and developers. The project combines the ease of use of Steam with the open distribution model of itch.io, providing a free and fair platform for indie content distribution.

### Key Features

- 🎮 **Game Library** — manage all your indie games in one place
- 🛒 **Game Store** — open marketplace with search and filtering
- 📦 **Installation & Updates** — automatic game installation and updates
- 🔐 **Secure Authentication** — sign in via OAuth (GitHub/Twitch) or email
- 🎨 **Modern Interface** — intuitive UI built with Vue 3
- 🚀 **Cross-platform** — support for Windows, macOS, and Linux

## Download

### Latest Release

Download the latest version for your platform:

- **Windows** — [Download .exe](https://github.com/rodd-oss/zapuskalka/releases/latest/download/Zapuskalka_0.3.0_x64-setup.exe) or [Download .msi](https://github.com/rodd-oss/zapuskalka/releases/latest/download/Zapuskalka_0.3.0_x64_en-US.msi)
- **macOS** — [Download .dmg](https://github.com/rodd-oss/zapuskalka/releases/latest/download/Zapuskalka_0.3.0_aarch64.dmg) or [Download .app.tar.gz](https://github.com/rodd-oss/zapuskalka/releases/latest/download/Zapuskalka_0.3.0_aarch64.app.tar.gz)
- **Linux** — [Download .AppImage](https://github.com/rodd-oss/zapuskalka/releases/latest/download/Zapuskalka_0.3.0_x86_64.AppImage) or [Download .deb](https://github.com/rodd-oss/zapuskalka/releases/latest/download/Zapuskalka_0.3.0_amd64.deb)

📦 [All releases and versions](https://github.com/rodd-oss/zapuskalka/releases)

### macOS Installation

After downloading and installing the application:

1. Drag Zapuskalka to the Applications folder
2. Open Terminal
3. Run the following command to remove the quarantine attribute:

```bash
sudo xattr -r -c /Applications/Zapuskalka.app
```

The application is now ready to launch!

---

## Development Guide

### Requirements

Before starting development, make sure you have installed:

- **Bun** — [Installation guide](https://bun.com/docs/installation)
- **Node.js** 20.19+ or 22.12+ — [Download](https://nodejs.org/en/download)
- **Rust** — [Installation guide](https://www.rust-lang.org/tools/install)
- **Taskfile** — [Installation guide](https://taskfile.dev/docs/installation#get-the-binary)

### Install Dependencies

Run in the project root:

```bash
bun install
```

### Create Backend Admin Account

1. Start the backend:

```bash
task dev-backend
```

2. Open the URL from the terminal and create a local admin account
3. Navigate to the users table, enable and create a user account
4. Stop the backend service

### Run Development Mode

To run the entire project in development mode:

```bash
task dev
```

---

## License

The project is distributed under the MPLv2 license. See the [LICENSE](LICENSE) file for details.

## Links

- 📖 [Product Documentation](docs/PRODUCT.md)
- 🏗️ [Project Architecture](docs/ARCHITECTURE.md)
- 🐛 [Report an Issue](https://github.com/rodd-oss/zapuskalka/issues)
- 💬 [Discussions](https://github.com/rodd-oss/zapuskalka/discussions)
