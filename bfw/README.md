# Bambu Lab Filament Watcher Add-on (`bfw`)

This folder contains the Home Assistant add-on definition.

The add-on runtime is provided by a prebuilt GHCR image published from the app repository:

- `ghcr.io/yourdawi/bfw-app`

## Files

- `config.yaml` - add-on metadata and options schema
- `Dockerfile` - minimal image definition (`FROM ${BFW_IMAGE}`)
- `build.yaml` - architecture mapping + image argument

## Versioning

Version pinning is controlled in `build.yaml`:

```yaml
args:
  BFW_IMAGE: ghcr.io/yourdawi/bfw-app:latest
```
