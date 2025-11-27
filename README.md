# Install Guide

## MacOS

- download dmg
- drag Zapuskalka to application folder
- open terminal
- execute command
``` bash
sudo xattr -r -c /Applications/Zapuskalka.app
```
- you are ready to launch

# Development guide

## Setup

### Requirments

- install bun - https://bun.com/docs/installation
- install Node.js 20.19+ or 22.12+ - https://nodejs.org/en/download
- install go - https://go.dev/dl/
- install taskfile - https://taskfile.dev/docs/installation#get-the-binary

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
