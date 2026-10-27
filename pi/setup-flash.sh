
# on the Pi (stop anything using /dev/ttyACM0 first, e.g. meshcli)
python3 -m venv ~/nrfutil && ~/nrfutil/bin/pip install adafruit-nrfutil
~/nrfutil/bin/adafruit-nrfutil --verbose dfu serial \
  --package RAK_4631_repeater_bridge_rs232_serial1-*.zip \
  -p /dev/ttyACM0 -b 115200 --singlebank --touch 1200
