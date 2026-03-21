# Emergency Mode Service

**Goal** : When a remote device looses internet connection, enter "emergency mode" where instead of trying to connect to a network, host a network that other devices can connect to perform actions

**Why** : I have a raspberry as my server/nas that is connected to Wifi and can be access in the local network via ssh. When power goes out, an UPS keeps it working *but* it looses internet connection. So, I wanted an easy way to access it with my phone to be able to shutdown safely before turning off the UPS. Also .. wanted to see if I could build this :)

**How** : The project is split into 3 services

- Detector : every T time it checks if it can access the router's gateway.
  - If it can't for a period of time/tries, it enters "outage" mode starts the `Handler` service. 
  - When in "outage" mode, its reversed. every T, it exists "outage" mode to check if the router's gateway is accessible again
- Handler : it starts/stops the emergency AP, as well as the `WebApp`
- WebApp : simple web app to allow a remote device (eg: smartphone) to click a big red button and issue the shutdown command

note: (in debug) check http://localhost:9999

Where applicable, replace {service-path} with the folder path where project exists

## SystemD

### Detector

Create `sudo nano /etc/systemd/system/emergency-detector.service`

```
[Unit]
Description=Power Outage Detection
After=network-online.target

[Service]
ExecStart={service-path}/detector/power_check.sh
User=vessel
Group=vessel
```

Create `sudo nano /etc/systemd/system/emergency-detector.timer`

```
[Unit]
Description=Run Power Outage Detection every 2 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=2min
Unit=emergency-detector.service

[Install]
WantedBy=timers.target
```

### Handler
Create `sudo nano /etc/systemd/system/emergency-handler.service`

```
[Unit]
Description=Emergency Access Point
After=network.target

[Service]
Type=oneshot
ExecStart={service-path}/handler/mode_handler.sh start
ExecStop={service-path}/handler/mode_handler.sh stop
RemainAfterExit=yes
User=vessel
Group=vessel

[Install]
WantedBy=multi-user.target
```

### WebApp
Create `sudo nano /etc/systemd/system/emergency-web.service`

```
[Unit]
Description=Emergency Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 {service-path}/webapp/app.py
Restart=on-failure
User=vessel
Group=vessel

[Install]
WantedBy=multi-user.target
```


### Start & Stop

```bash
sudo systemctl start <service-name-here>.service 
sudo systemctl stop <service-name-here>.service 

sudo systemctl enable --now emergency-detector.timer
sudo systemctl disable emergency-detector.timer
```

### Useful commands

Check it's working

```bash
systemctl list-timers | grep <service-name-here>
```

Check schedule
```bash
systemctl list-timers <service-name-here>.timer
```

View logs

```bash
journalctl -u <service-name-here>.service -f
```

## AP Configs

```bash
sudo apt-get install hostapd
sudo apt-get install dnsmasq
sudo systemctl unmask hostapd

sudo systemctl disable hostapd
sudo systemctl disable dnsmasq
```

```bash
sudo mkdir -p /etc/emergency_ap
sudo chmod 755 /etc/emergency_ap

sudo nano /etc/emergency_ap/hostapd.conf
```

```ini
#2.4GHz setup
interface=wlan0
driver=nl80211
ssid=Berry-Emergency-AP
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=raspberry_pi
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP TKIP
rsn_pairwise=CCMP
#Country Info
country_code=PT
ieee80211n=1
ieee80211d=1
```


```bash
sudo nano /etc/emergency_ap/dnsmasq.conf
```

```ini
interface=wlan0
bind-dynamic
dhcp-range=192.168.50.10,192.168.50.100,255.255.255.0,24h
dhcp-option=3,192.168.50.1
dhcp-option=6,192.168.50.1
server=1.1.1.1
log-queries
log-dhcp
```

```bash
sudo nano /etc/emergency_ap/network_ap.conf
```

```ini
auto wlan0
iface wlan0 inet static
  address 192.168.50.1
  netmask 255.255.255.0
```

## Rotate Logs

```bash
sudo nano /etc/logrotate.d/emergency_service
```

```
{service-path}/_log/handler.log {
    weekly                 # Rotate once per week (default: usually Sunday via cron)
    rotate 3               # Keep 3 old log files (e.g., handler.log.1.gz → handler.log.3.gz)
    compress               # Compress old versions with gzip
    delaycompress          # Compress the log from 2 weeks ago, not the last rotation (safer)
    missingok              # Don’t error if the log file doesn’t exist
    notifempty             # Skip rotation if file is empty
    create 644 vessel vessel  # Recreate new log with correct ownership and permissions
    dateext                # Adds date suffixes (e.g., handler.log-2025-11-09.gz)
}
```