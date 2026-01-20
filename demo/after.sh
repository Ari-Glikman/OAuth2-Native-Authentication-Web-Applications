#!/bin/bash
set -euo pipefail
echo "[after.sh] Running post-start setup (compile + seed + users + web app)..."
iris session IRIS < /tmp/iris.script
echo "[after.sh] Post-start setup done."
