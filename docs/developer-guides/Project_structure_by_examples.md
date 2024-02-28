# Project structure by examples

- [Project structure by examples](#project-structure-by-examples)
  - [Golang](#golang)
    - [Directory structure](#directory-structure)
    - [Commands](#commands)

## Golang

### Directory structure

```console
build/
  .gitignore
cmd/
  ${program-name}/
    arguments.go
    arguments_test.go
    config.go
    config_test.go
    main.go
    main_test.go
go.mod
go.sum
```

### Commands

```console
go test -coverprofile=coverage.out  -v ./...
go tool cover -html=coverage.out -o coverage.html
```

```console
go build -o ./build/${program-name} ./cmd/${program-name}/
```
