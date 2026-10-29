#!/bin/bash
#
# 90-copy-bin-scripts.sh
#
# Copy helper scripts into ~meshcore/bin directory
#

# overall bridge helpers

# corescope helpers
cfiles="check-corescope-services.sh show-mosquitto-observed.sh show-mosquitto-packets.sh"

for f in ${cfiles}
do
  cp corescope/${f} bin/
  chmod 700 bin/${f}
done

