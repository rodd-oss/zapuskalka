# Development guide

## Setup

### Requirments

- install bun - https://bun.com/docs/installation
- install go - https://go.dev/dl/
- install taskfile - https://taskfile.dev/docs/installation#get-the-binary
- install wails by running command:

```bash
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```

- Vite requires Node.js version 20.19+ or 22.12+. Check your node version by running command

```bash
node -v
```

Upgrade your nodejs - https://nodejs.org/en/download

### Install dependencies

Run this command in the project root

```bash
bun install
```

### Create backend admin account

- Launch backend

```bash
task dev-backend
```

- Open url from the terminal and create local admin account
- Navigate to the users table enable and create user acount
- Stop backend service

## Devolopment

### Run dev mode

```bash
task dev
```

### Build

```bash
task build
```
