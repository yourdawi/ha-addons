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

Notes
- The run script will attempt to exec a `nebula-sync` binary from PATH. If the upstream image provides a different binary or a custom entrypoint that expects arguments, the Dockerfile uses `/run.sh` as the container `CMD` — this matches other add-ons in this repository.
- If you want me to adapt the wrapper to call a specific command or to preserve an upstream entrypoint, tell me which command the upstream image expects and I will update the files.
