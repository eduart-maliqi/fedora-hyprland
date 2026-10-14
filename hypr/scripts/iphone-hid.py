#!/usr/bin/env python3
"""★ 8155 – Laptop als Bluetooth-LE-Maus + Tastatur (HID over GATT) fürs iPhone

  iphone-hid.py          Dienst: wirbt als „8155-Laptop-HID“, nimmt Befehle am Socket
                         $XDG_RUNTIME_DIR/iphone-hid.sock entgegen (je Befehl ein Datagramm):
                           m <dx> <dy> [rad]    Mausbewegung / Mausrad (relativ)
                           b <maske>            Maustasten (Bit 0 links, 1 rechts, 2 mitte)
                           k <mods> [taste …]   Tastatur (HID-Usage-IDs, bis 6 Tasten); „k 0“ lässt alle los
  Gesteuert von iphone-steuern.py. iPhone: Einstellungen → Bedienungshilfen → Tippen → AssistiveTouch an,
  dann unter Bluetooth „8155-Laptop-HID“ koppeln.
"""
import os
import socket
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

APP = "/org/eight155/hid"
SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "iphone-hid.sock")
NAME = "8155-Laptop-HID"

# Report 1 = Maus (3 Tasten, X, Y, Rad), Report 2 = Tastatur (Modifier, 6 Tasten)
REPORT_MAP = bytes.fromhex("".join([
    "05 01 09 02 A1 01 85 01 09 01 A1 00 05 09 19 01 29 03 15 00 25 01 95 03 75 01 81 02 95 01 75 05 81 03",
    "05 01 09 30 09 31 09 38 15 81 25 7F 75 08 95 03 81 06 C0 C0",
    "05 01 09 06 A1 01 85 02 05 07 19 E0 29 E7 15 00 25 01 75 01 95 08 81 02 95 01 75 08 81 03",
    "95 06 75 08 15 00 25 65 05 07 19 00 29 65 81 00 C0",
]).replace(" ", ""))
OBJ_PROPS = "org.freedesktop.DBus.Properties"


class Obj(dbus.service.Object):
    iface = ""

    def props(self):
        return {}

    @dbus.service.method(OBJ_PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.props()

    @dbus.service.method(OBJ_PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.props()[name]

    @dbus.service.signal(OBJ_PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass


class Service(Obj):
    iface = "org.bluez.GattService1"

    def __init__(self, bus, app, uuid):
        self.path = f"{APP}/s{len(app.objs)}"
        self.uuid, self.chars = uuid, []
        app.objs.append(self)
        super().__init__(bus, self.path)

    def props(self):
        return {"UUID": self.uuid, "Primary": True,
                "Characteristics": dbus.Array([dbus.ObjectPath(c.path) for c in self.chars], signature="o")}


class Char(Obj):
    iface = "org.bluez.GattCharacteristic1"

    def __init__(self, bus, app, svc, uuid, flags, value=b"", report_ref=None):
        self.path = f"{svc.path}/c{len(svc.chars)}"
        self.svc, self.uuid, self.flags, self.value = svc, uuid, flags, bytes(value)
        self.notifying, self.descs = False, []
        svc.chars.append(self)
        app.objs.append(self)
        super().__init__(bus, self.path)
        if report_ref:
            Desc(bus, app, self, "2908", ["read"], report_ref)

    def props(self):
        return {"UUID": self.uuid, "Service": dbus.ObjectPath(self.svc.path),
                "Flags": dbus.Array(self.flags, signature="s"),
                "Descriptors": dbus.Array([dbus.ObjectPath(d.path) for d in self.descs], signature="o")}

    @dbus.service.method("org.bluez.GattCharacteristic1", in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        return dbus.Array([dbus.Byte(b) for b in self.value], signature="y")

    @dbus.service.method("org.bluez.GattCharacteristic1", in_signature="aya{sv}")
    def WriteValue(self, value, options):
        self.value = bytes(value)

    @dbus.service.method("org.bluez.GattCharacteristic1")
    def StartNotify(self):
        self.notifying = True

    @dbus.service.method("org.bluez.GattCharacteristic1")
    def StopNotify(self):
        self.notifying = False

    def notify(self, data):
        self.value = bytes(data)
        if self.notifying:
            self.PropertiesChanged("org.bluez.GattCharacteristic1",
                                   {"Value": dbus.Array([dbus.Byte(b) for b in self.value], signature="y")}, [])


class Desc(Obj):
    iface = "org.bluez.GattDescriptor1"

    def __init__(self, bus, app, char, uuid, flags, value):
        self.path = f"{char.path}/d{len(char.descs)}"
        self.char, self.uuid, self.flags, self.value = char, uuid, flags, bytes(value)
        char.descs.append(self)
        app.objs.append(self)
        super().__init__(bus, self.path)

    def props(self):
        return {"UUID": self.uuid, "Characteristic": dbus.ObjectPath(self.char.path),
                "Flags": dbus.Array(self.flags, signature="s")}

    @dbus.service.method("org.bluez.GattDescriptor1", in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        return dbus.Array([dbus.Byte(b) for b in self.value], signature="y")


class App(dbus.service.Object):
    def __init__(self, bus):
        self.objs = []
        super().__init__(bus, APP)

    @dbus.service.method("org.freedesktop.DBus.ObjectManager", out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        return {dbus.ObjectPath(o.path): {o.iface: o.props()} for o in self.objs}


class Advert(Obj):
    iface = "org.bluez.LEAdvertisement1"
    path = APP + "/adv"

    def __init__(self, bus):
        super().__init__(bus, self.path)

    def props(self):
        return {"Type": "peripheral", "ServiceUUIDs": dbus.Array(["1812"], signature="s"),
                "LocalName": NAME, "Appearance": dbus.UInt16(0x03C2)}

    @dbus.service.method("org.bluez.LEAdvertisement1")
    def Release(self):
        pass


def die(err):
    print("BlueZ-Fehler:", err, file=sys.stderr)
    sys.exit(1)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    adapter = bus.get_object("org.bluez", "/org/bluez/hci0")
    ap = dbus.Interface(adapter, OBJ_PROPS)
    ap.Set("org.bluez.Adapter1", "Powered", True)
    ap.Set("org.bluez.Adapter1", "Pairable", True)

    app = App(bus)
    hid = Service(bus, app, "1812")
    Char(bus, app, hid, "2A4A", ["read"], [0x11, 0x01, 0x00, 0x02])
    Char(bus, app, hid, "2A4C", ["write-without-response"])
    Char(bus, app, hid, "2A4E", ["read", "write-without-response"], [1])
    Char(bus, app, hid, "2A4B", ["read"], REPORT_MAP)
    mouse = Char(bus, app, hid, "2A4D", ["encrypt-read", "notify"], [0, 0, 0, 0], report_ref=[1, 1])
    kbd = Char(bus, app, hid, "2A4D", ["encrypt-read", "notify"], [0] * 8, report_ref=[2, 1])
    # iOS erwartet Geräteinformation und Akku, sonst bricht die Kopplung gern ab
    info = Service(bus, app, "180A")
    Char(bus, app, info, "2A29", ["read"], b"8155")
    Char(bus, app, info, "2A50", ["read"], [0x02, 0x6B, 0x1D, 0x46, 0x02, 0x10, 0x01])
    bat = Service(bus, app, "180F")
    Char(bus, app, bat, "2A19", ["read"], [100])

    buttons = 0

    def send_mouse(dx=0, dy=0, wheel=0):
        clamp = lambda v: max(-127, min(127, v))
        while True:
            x, y, w = clamp(dx), clamp(dy), clamp(wheel)
            mouse.notify([buttons, x & 0xFF, y & 0xFF, w & 0xFF])
            dx, dy, wheel = dx - x, dy - y, wheel - w
            if not (dx or dy or wheel):
                return

    def command(data):
        nonlocal buttons
        p = data.decode(errors="replace").split()
        try:
            if p[0] == "m":
                send_mouse(int(p[1]), int(p[2]), int(p[3]) if len(p) > 3 else 0)
            elif p[0] == "b":
                buttons = int(p[1]) & 7
                send_mouse()
            elif p[0] == "k":
                keys = [int(k) for k in p[2:8]]
                kbd.notify([int(p[1]) & 0xFF, 0] + keys + [0] * (6 - len(keys)))
        except (IndexError, ValueError):
            pass

    if os.path.exists(SOCK):
        os.unlink(SOCK)
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(SOCK)
    os.chmod(SOCK, 0o600)

    def on_sock(fd, cond):
        command(sock.recv(256))
        return True

    GLib.io_add_watch(sock.fileno(), GLib.IO_IN, on_sock)

    dbus.Interface(adapter, "org.bluez.GattManager1").RegisterApplication(
        dbus.ObjectPath(APP), {}, reply_handler=lambda: print("GATT-Anwendung registriert"), error_handler=die)
    adv = Advert(bus)
    dbus.Interface(adapter, "org.bluez.LEAdvertisingManager1").RegisterAdvertisement(
        dbus.ObjectPath(adv.path), {}, reply_handler=lambda: print("wirbt als", NAME), error_handler=die)
    loop = GLib.MainLoop()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 15, loop.quit)   # SIGTERM: Socket aufräumen (systemd/pkill)
    try:
        loop.run()
    finally:
        if os.path.exists(SOCK):
            os.unlink(SOCK)


if __name__ == "__main__":
    main()
