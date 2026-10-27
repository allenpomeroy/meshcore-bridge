
epoctime="`date -u +%s`"

radioepoc="`mc-repeater-cli /dev/ttyACM0 clock`"

echo "radio $radioepoc"
echo "linux $epoctime"

mc-repeater-cli /dev/ttyACM0 "time $epoctime"
