mc-repeater-cli /dev/ttyACM0 "ver" "get bridge.type"
#   expect: v1.18.0 ...   and   > rs232

mc-repeater-cli /dev/ttyACM0 \
  "password q2d5f7g8H3J4K0N" \
  "set name Malko-Repeater2"
  "set radio 910.525,62.5,7,5" \
  "set repeat on" \
  "set bridge.baud 115200" \
  "set bridge.source tx" \
  "set bridge.delay 500" \
  "set bridge.enabled on"

mc-repeater-cli /dev/ttyACM0 "reboot"   # USB drops during the reboot; a serial error here is expected

echo "wait for radio reboot"
sleep 10

# after ~10 s, verify:
mc-repeater-cli /dev/ttyACM0 "get radio" "get repeat" \
  "get bridge.enabled" "get bridge.source" "get bridge.baud" "get bridge.delay"
