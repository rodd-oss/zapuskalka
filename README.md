# Development guide

## Requirments
- install bun - https://bun.com/docs/installation
- install go - https://go.dev/dl/
- install taskfile - https://taskfile.dev/docs/installation#get-the-binary
- install wails by running command:
```bash
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```

Now install all node_modules by running command in the project root folder
```bash
bun install
```
## Run dev mode

```bash
task dev
```

## Build

```bash
task build
```
