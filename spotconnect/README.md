# SpotConnect (Home Assistant Add-on)

Run [philippe44/SpotConnect](https://github.com/philippe44/SpotConnect) as a Home Assistant add-on to expose virtual AirPlay/DLNA devices for Spotify Connect.

## Features
- Always fetch and run the latest upstream SpotConnect release at startup (releases/latest)
- Auto-select the correct binary for your architecture (optionally prefer static builds)
- Optional caching to avoid re-downloading until a new upstream release is available

## Installation
- Add repository: `https://github.com/yourdawi/ha-addons`
- Install the add-on "SpotConnect"

## Configuration
- `spotconnect_mode`: `raop` (AirPlay) or `upnp` (DLNA)
- `log_level`: `error`, `warn`, `info`, `debug`
- `network_select`: optional interface (e.g., `eth0`, `wlan0`)
- `prefer_static`: `yes`/`no` – prefer static binary if available
- `cache_binaries`: `true`/`false` – cache current version in `/config`; download only on new upstream releases

## Updates: How it works
- On every add-on start, the script checks the upstream latest release and downloads it if needed.


## Notes
- Uses host networking due to mDNS/Bonjour/SSDP requirements.
- Logs are available in the add-on logs panel.

## License
SpotConnect binaries are provided by the upstream project [philippe44/SpotConnect]. This add-on repository only packages and starts the service inside Home Assistant.
