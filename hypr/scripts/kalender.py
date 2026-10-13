#!/usr/bin/env python3
"""Termine für das Kontrollzentrum (quickshell/CalendarService.qml).

Liest alle Kalender aus der Evolution-Datenbank. Das Google-Konto steckt dort über die GNOME-Online-Konten,
dieses Skript braucht also kein eigenes Passwort oder Token.

  kalender.py [tage]     ab heute 0 Uhr, Standard 45 Tage

Ausgabe (JSON): {"events": [{"title", "start", "end", "allDay", "cal"}], "error": ""}
  start/end: lokale Zeit "YYYY-MM-DDTHH:MM"; ganztägig "YYYY-MM-DD" (end = letzter Tag, inklusive)
"""
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta


def lokal(t):
    """ICalTime → naives datetime in der Zeitzone des Rechners."""
    if t.is_date():
        return datetime(t.get_year(), t.get_month(), t.get_day())
    zone = t.get_timezone()
    if t.is_utc() or zone is not None:
        return datetime.fromtimestamp(t.as_timet_with_zone(zone))
    return datetime(t.get_year(), t.get_month(), t.get_day(), t.get_hour(), t.get_minute())


def quelle_lesen(src, von, bis, ECal):
    # 0 s würde ewig auf eine Verbindung warten, 1 s reicht: danach kommen die Daten aus dem lokalen Zwischenspeicher
    client = ECal.Client.connect_sync(src, ECal.ClientSourceType.EVENTS, 1, None)
    rohe = []
    client.generate_instances_sync(von, bis, None, lambda *a: (rohe.append(a), True)[1], None)
    out = []
    for comp, s, e, *_ in rohe:
        start, ende = lokal(s), lokal(e)
        ganztags = s.is_date()
        if ganztags:
            ende = max(start, ende - timedelta(days=1))
        fmt = "%Y-%m-%d" if ganztags else "%Y-%m-%dT%H:%M"
        out.append({"title": comp.get_summary() or "(ohne Titel)", "start": start.strftime(fmt),
                    "end": ende.strftime(fmt), "allDay": ganztags, "cal": src.get_display_name()})
    return out


def main():
    tage = int(sys.argv[1]) if len(sys.argv) > 1 else 45
    try:
        import gi
        gi.require_version("EDataServer", "1.2")
        gi.require_version("ECal", "2.0")
        gi.require_version("ICalGLib", "3.0")
        from gi.repository import ECal, EDataServer
        quellen = EDataServer.SourceRegistry.new_sync(None).list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR)
    except Exception as e:
        print(json.dumps({"events": [], "error": f"Evolution-Datenbank nicht erreichbar: {e}"}))
        return

    heute = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    von = int(heute.timestamp())
    bis = int((heute + timedelta(days=tage)).timestamp())

    events, fehler = [], []
    with ThreadPoolExecutor(max_workers=max(1, len(quellen))) as pool:
        futures = [(q, pool.submit(quelle_lesen, q, von, bis, ECal)) for q in quellen]
        for q, f in futures:
            try:
                events += f.result()
            except Exception as e:
                fehler.append(f"{q.get_display_name()}: {e}")

    events.sort(key=lambda ev: (ev["start"], ev["title"]))
    # nur melden, wenn gar nichts lesbar war – ein einzelner kaputter Kalender soll die Anzeige nicht kippen
    error = "; ".join(fehler) if fehler and len(fehler) == len(quellen) else ""
    print(json.dumps({"events": events, "error": error, "updated": int(time.time())}, ensure_ascii=False))


if __name__ == "__main__":
    main()
