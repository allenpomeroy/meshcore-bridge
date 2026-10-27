sudo tee /etc/corescope/config.json >/dev/null <<'EOF'
{
  "port": 3000,
  "dbPath": "/var/lib/corescope/meshcore.db",
  "mqttSources": [
    {
      "name": "intake",
      "broker": "mqtt://127.0.0.1:1884",
      "topics": ["meshcore/+/+/packets"]
    }
  ],
  "observerIATAWhitelist": ["TX1", "CO1", "MT1"],
  "channelKeys": {
    "Public": "8b3387e9c5cdea6ac9e5edbaa115cd72"
  },
  "hashChannels": ["#test"],
  "regions": {
    "TX1": "Texas",
    "CO1": "Colorado",
    "MT1": "Montana"
  },
  "mapDefaults": { "center": [40.0, -106.0], "zoom": 5 },
  "retention": { "nodeDays": 7, "observerDays": 14, "packetDays": 30 }
}
EOF
sudo chown root:corescope /etc/corescope/config.json && sudo chmod 640 /etc/corescope/config.json
python3 -m json.tool /etc/corescope/config.json >/dev/null && echo config-ok
