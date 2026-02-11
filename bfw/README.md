# Bambu Lab Filament Watcher Add-on (`bfw`)

This folder contains the Home Assistant add-on definition.

The add-on does **not** include app source code directly.  
It downloads a packaged app release from:

- `https://github.com/yourdawi/bambulab-filament-watcher`

## Files in This Folder

- `config.yaml` - Home Assistant add-on metadata and options schema
- `Dockerfile` - builds the add-on image and downloads the app package
- `build.yaml` - multi-architecture base image mapping

## How Versioning Works

`Dockerfile` contains:

```dockerfile
ARG BFW_VERSION=v2.1.0
```

That value must match an existing release asset in the app repository:

`bfw-app-v2.1.0.tar.gz`


## Optional Repository Override

You can also change:

```dockerfile
ARG BFW_REPO=yourdawi/bambulab-filament-watcher
```

to point to a fork or another owner.
