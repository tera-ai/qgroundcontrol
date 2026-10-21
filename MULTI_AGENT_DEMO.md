# Multi-agent demo support (branch `dev/multi-agent-demo`)

This branch adds what TGroundControl needs for the PAS-Tera-AI GPS-denied
air-ground demo: drones survey a site without GPS, a ground station builds a
driving map from their imagery, and trucks plan and drive on it. The demo
itself lives in PAS-Tera-AI, branch `dev/gps-denied-demo`,
`demo/gps_denied/`. Its `README.md` explains the system and `AGENT_HANDOFF.md` is
the handoff for an agent continuing the work.

## What this branch changes

| File | Change |
|---|---|
| `src/FlyView/MultiAgentDemoPanel.qml` | The multi-agent demo panel on the Fly view (below). |
| `src/FlyView/FlyViewCustomLayer.qml`, `src/FlyView/CMakeLists.txt` | Place the panel at the top centre and register it. |
| `src/Vehicle/Vehicle.cc`, `Vehicle.h` | `NAMED_VALUE_INT` and `NAMED_VALUE_FLOAT` are kept per vehicle and exposed to QML as `namedValues`. |
| `src/AutoPilotPlugins/AutoPilotPlugin.cc` | No Vehicle Configuration prompt when `TGC_NO_SETUP_PROMPT` is set or several vehicles are connected. |
| `src/Vehicle/MultiVehicleManager.cc` | No modal "Connected to Vehicle N" with `TGC_NO_SETUP_PROMPT`: every vehicle reconnects each run, and the message covered the map until dismissed. |
| `src/FlightMap/FlightMap.qml` | Accept wheel events from XWayland's relative pointer (Qt reports it as a touchpad), so the map zooms under xcb. |
| `src/MAVLink/LibEvents/CMakeLists.txt` | libevents pinned to the commit before it needed newer MAVLink helpers. |

## The panel

The panel shows only while a vehicle that publishes the demo state is
connected. Those are the demo's truck endpoints, `terademo.truck_mavlink`,
which send `NAMED_VALUE_INT` at 1 Hz:

- `DEMO_PH`: the orchestrator phase
- `SURVEYED`: bit n−1 set when drone system n has its survey
- `MAP_RDY`
- `GOAL_SET`
- `TASK`: 0 idle, 1 driving, 2 reached, 3 failed

It walks the operator through:

1. **Plan the drones' survey.** A button per drone opens the Plan view.
2. **Set each truck's goal.** Click "Set goal", then the map. This sends
   command 31020 with latitude and longitude in params 5 and 6.
3. **Start the ground missions.** This sends `MAV_CMD_MISSION_START` to
   each truck, and is enabled once the map is published and every truck has
   a goal.

Drones are the multirotor vehicles and trucks are the ones that publish
`DEMO_PH`. Any number of each works. Vehicles whose link is lost are left
out, so a vehicle from an earlier run or one dropped from the demo's config
doesn't hold up step 1.

## The drones' map overlay

Once `MAP_RDY` is 1, the panel fetches `http://127.0.0.1:8765/overlay.json`
from the demo's map server and draws `overlay.png` on the Fly view map,
under the vehicles and goal markers:

- blocked ground in red
- roads in green
- roadblocks, canopies and other obstacles outlined

`overlay.json` gives the image's north-west and south-east corners and the
Qt map zoom level at which it is at natural size; the demo's
`terademo.mapping.overlay_placement` writes it. A legend and a Hide/Show
button sit in the panel.

## Building and running

Build with Qt 6.10.1:

```bash
cmake -B build -G Ninja -DCMAKE_PREFIX_PATH=<Qt>/6.10.1/gcc_64 -DQGC_ENABLE_GST_VIDEOSTREAMING=OFF
cmake --build build
```

The demo's local build is `/mnt/storage2/sources/qgc-build`, and
`paths.tgc` in the demo's `config/demo.yaml` points at it. The demo starts it
with `scripts/tgc.sh`, which sets `TGC_NO_SETUP_PROMPT=1`. To record the
window for the demo video, start it on XWayland:
`QT_QPA_PLATFORM=xcb scripts/tgc.sh`.
