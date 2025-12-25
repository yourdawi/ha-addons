Nebula-Sync add-on

This add-on wraps the upstream `ghcr.io/lovelaze/nebula-sync` image to run as a Home Assistant add-on.

Configuration
- `primary`: Primary server in the form `http://host|password` (string)
- `replicas`: Comma-separated list of replica servers `http://host|password,...` (string)
- `full_sync`: Boolean to enable full sync (true/false)
- `run_gravity`: Boolean to enable gravity-like sync (true/false)
- `cron`: Cron schedule for sync jobs (string)

Usage
- Edit the add-on options in Home Assistant UI or place them in `/data/options.json`.
- The wrapper exports the options as environment variables consumed by the upstream image.
