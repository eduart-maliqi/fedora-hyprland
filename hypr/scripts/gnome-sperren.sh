#!/bin/sh
# GDM meldet automatisch an – unter GNOME gleich sperren, damit auch dort das Passwort nötig ist.
# Wiederholen, weil die gnome-shell beim Autostart ihre D-Bus-Schnittstelle evtl. noch nicht anbietet.
for i in $(seq 40); do
    gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.Lock >/dev/null 2>&1 && exit 0
    sleep 0.5
done
exit 1
