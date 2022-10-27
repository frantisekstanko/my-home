#!/bin/bash

redshift=3200
brightness=25

redshift -P -O "$redshift"
brightnessctl set "${brightness}%"

mkdir -p /tmp/redshift/
mkdir -p /tmp/i3/logs/

echo "$redshift" > /tmp/redshift/value

dbus-update-activation-environment --systemd DISPLAY

if [ -f /usr/bin/gnome-keyring-daemon ]; then
  eval "$(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
  export SSH_AUTH_SOCK
fi

exec /usr/bin/i3 > "/tmp/i3/logs/$(date +'%Y-%m-%d_%H-%M-%S')" 2>&1

