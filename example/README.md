# spinifyapp

Spinify App Example

## Code generation

```bash
$ make codegen
```

## Localization

```bash
$ code lib/src/common/localization/intl_en.arb
$ make intl
```

## Recreating the project

**! Warning: This will overwrite all files in the current directory.**

```bash
fvm spawn beta create --overwrite -t app --project-name "spinifyapp" --org "dev.plugfox.spinify" --description "Spinify App Example" --platforms ios,android,windows,linux,macos,web .
```
