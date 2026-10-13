#!/usr/bin/bash
# ★ 8155 – installiert „ghost“: GRUB-Bootmenü wie der Startbildschirm von Ghost of Tsushima + Plymouth-Ladebildschirm.
# Als root ausführen:  pkexec ~/.config/hypr/grub-ghost/installieren.sh > /tmp/ghost.log 2>&1   (Ausgabe nie pipen!)
# Kann beliebig oft laufen (z. B. nach neuem Bild): Themes werden ersetzt, grub.cfg + initramfs neu erzeugt.
# Sichert beim ersten Mal /etc/default/grub, /boot/grub2/grub.cfg, /etc/plymouth/plymouthd.conf (*.vor-ghost-<datum>)
# → rueckgaengig.sh.
set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
THEME=/boot/grub2/themes/ghost
STAMP=$(date +%Y%m%d-%H%M)

[ "$(id -u)" = 0 ] || { echo "Bitte als root ausführen: pkexec $0" >&2; exit 1; }
trap 'echo "ABBRUCH (Zeile $LINENO) – /boot/grub2/grub.cfg ist unverändert. Alten Zustand herstellen: rueckgaengig.sh" >&2' ERR
for f in theme.txt load.txt background.jpg background_load.jpg select_c.png load_select_c.png schrift.ttf icons/ghost-fedora.png icons/ghost-windows.png; do
	[ -f "$SRC/theme/$f" ] || { echo "Fehlt: $SRC/theme/$f" >&2; exit 1; }
done
for f in ghost.plymouth ghost.script szene.png schwarz.png laden.png flocke_1.png; do
	[ -f "$SRC/plymouth/$f" ] || { echo "Fehlt: $SRC/plymouth/$f" >&2; exit 1; }
done

# 1. Sicherung (nur beim ersten Mal, damit rueckgaengig.sh den Zustand von vorher findet)
if ! ls /etc/default/grub.vor-ghost-* > /dev/null 2>&1; then
	cp -a /etc/default/grub "/etc/default/grub.vor-ghost-$STAMP"
	cp -a /boot/grub2/grub.cfg "/boot/grub2/grub.cfg.vor-ghost-$STAMP"
	echo "Sicherung: /etc/default/grub.vor-ghost-$STAMP, /boot/grub2/grub.cfg.vor-ghost-$STAMP"
fi
if ! ls /etc/plymouth/plymouthd.conf.vor-ghost-* > /dev/null 2>&1; then
	cp -a /etc/plymouth/plymouthd.conf "/etc/plymouth/plymouthd.conf.vor-ghost-$STAMP"
	echo "Sicherung: /etc/plymouth/plymouthd.conf.vor-ghost-$STAMP"
fi

# 2. Theme nach /boot (ext4 – GRUB liest es dort schneller und sicherer als vom btrfs-Root)
rm -rf "$THEME"
install -d -m 755 "$THEME"
install -m 644 "$SRC"/theme/*.txt "$SRC"/theme/*.png "$SRC"/theme/*.jpg "$SRC"/theme/*.ttf "$THEME"/
install -d -m 755 "$THEME/icons"
install -m 644 "$SRC"/theme/icons/*.png "$THEME/icons/"
rm -f "$THEME"/*preview*

# 3. Menü-Skript; die Einträge von 10_linux und 30_uefi-firmware übernimmt es
install -m 755 "$SRC/15_ghost_menu" /etc/grub.d/15_ghost_menu
chmod -x /etc/grub.d/10_linux /etc/grub.d/30_uefi-firmware
install -m 755 "$SRC/95-ghost-menu.install" /etc/kernel/install.d/95-ghost-menu.install

# 4. /etc/default/grub: Theme, Auflösung des Laptops, os-prober aus (Windows-Eintrag kommt aus 15_ghost_menu)
set_var() {
	if grep -q "^#\?$1=" /etc/default/grub; then
		sed -i "s|^#\?$1=.*|$1=$2|" /etc/default/grub
	else
		echo "$1=$2" >> /etc/default/grub
	fi
}
set_var GRUB_THEME "\"$THEME/theme.txt\""
set_var GRUB_GFXMODE "2880x1800,auto"
set_var GRUB_DISABLE_OS_PROBER "true"
set_var GRUB_TIMEOUT "-1"                 # nie automatisch starten – Menü wartet auf eine Auswahl
# 00_header setzt gfxmode nur, wenn loadfont klappt – unter Secure Boot nie → über die grubenv, die GRUB zuerst lädt
grub2-editenv /boot/grub2/grubenv set gfxmode=2880x1800,auto

# 5. grub.cfg erzeugen, prüfen, erst dann ersetzen
NEU=/boot/grub2/grub.cfg.ghost-neu
rm -f "$NEU" "$NEU.new"                   # Reste eines abgebrochenen Laufs
grub2-mkconfig -o "$NEU"
fehler=""
grub2-script-check "$NEU" || fehler="grub2-script-check meldet Fehler"
grep -q "submenu 'FEDORA LINUX'" "$NEU" || fehler="Eintrag FEDORA LINUX fehlt"
grep -q "^	blscfg" "$NEU" || fehler="blscfg fehlt"
grep -q "themes/ghost/theme.txt" "$NEU" || fehler="Theme nicht eingebunden"
grep -q -- "--class ghost-k-" "$NEU" || fehler="LOAD GAME hat keine Kernel-Einträge"
ls "$THEME"/icons/ghost-k-*.png > /dev/null 2>&1 || fehler="Bilder der Kernel-Einträge fehlen (python3 + Pillow?)"
grep -q "^  set timeout=-1" "$NEU" || fehler="Timeout ist nicht -1 (Menü würde automatisch starten)"
grep -q "^menuentry 'Windows Boot Manager" "$NEU" && fehler="os-prober-Eintrag noch da (doppeltes Windows)"
grep -q "^menuentry 'WINDOWS'" "$NEU" || fehler="Eintrag WINDOWS fehlt (bootmgfw.efi nicht gefunden?)"
grep -q "^blscfg" "$NEU" && fehler="10_linux ist noch aktiv (doppelte Kernel-Einträge)"
[ "$(grep -c "^submenu 'FEDORA LINUX'" "$NEU")" = 1 ] || fehler="FEDORA LINUX mehrfach (fremdes Skript in /etc/grub.d?)"
[ "$(grep -c "^menuentry 'WINDOWS'" "$NEU")" = 1 ] || fehler="WINDOWS mehrfach (fremdes Skript in /etc/grub.d?)"
if [ -n "$fehler" ]; then
	echo "ABBRUCH: $fehler – grub.cfg bleibt unverändert ($NEU zum Nachsehen)." >&2
	exit 1
fi
chmod 600 "$NEU"
mv "$NEU" /boot/grub2/grub.cfg
echo
echo "== Menü in /boot/grub2/grub.cfg =="
sed -n '/^### BEGIN \/etc\/grub.d\/15_ghost_menu/,/^### END \/etc\/grub.d\/15_ghost_menu/p' /boot/grub2/grub.cfg
echo "== ausführbare Skripte in /etc/grub.d =="
find /etc/grub.d -maxdepth 1 -type f -perm -u+x -printf '%f\n' | sort | tr '\n' ' '
echo
trap 'echo "ABBRUCH (Zeile $LINENO) im Plymouth-Teil – GRUB ist schon fertig. Zurück: rueckgaengig.sh" >&2' ERR

# 6. Plymouth: animierter Ladebildschirm (Skript-Plugin, Theme, DeviceScale=1, initramfs neu)
PLY=/usr/share/plymouth/themes/ghost
rpm -q plymouth-plugin-script > /dev/null || dnf install -y plymouth-plugin-script
rm -rf "$PLY"
install -d -m 755 "$PLY"
install -m 644 "$SRC"/plymouth/*.png "$SRC"/plymouth/ghost.script "$SRC"/plymouth/ghost.plymouth "$PLY"/
cat > /etc/plymouth/plymouthd.conf << 'KONF'
# ★ 8155 – Plymouth: Theme „ghost“ (animierter Ladebildschirm wie Ghost of Tsushima), Quellen ~/.config/hypr/grub-ghost.
# Übrige Werte aus /usr/share/plymouth/plymouthd.defaults. DeviceScale=1: die Bilder sind für 2880×1800 Pixel gemacht
# (sonst rechnet Plymouth auf dem HiDPI-Bildschirm mit 1440×900 und vergrößert unscharf). Zurück: rueckgaengig.sh
[Daemon]
Theme=ghost
DeviceScale=1
KONF
# Das Theme muss ins initramfs: für jeden Kernel mit Boot-Eintrag neu bauen (Rettungssystem bleibt, wie es ist)
for k in /boot/vmlinuz-*; do
	kver=${k#/boot/vmlinuz-}
	case "$kver" in 0-rescue-*) continue ;; esac
	[ -d "/lib/modules/$kver" ] || continue
	echo "initramfs $kver …"
	dracut -f "/boot/initramfs-$kver.img" "$kver"
	# grep -c liest alles: grep -q würde lsinitrd per SIGPIPE abbrechen und mit pipefail einen Fehlalarm geben
	if [ "$(lsinitrd "/boot/initramfs-$kver.img" | grep -c "themes/ghost/ghost.script")" -gt 0 ]; then
		echo "  ok: Theme ghost drin ($(du -h "/boot/initramfs-$kver.img" | cut -f1))"
	else
		echo "  WARNUNG: Theme ghost fehlt im initramfs $kver" >&2
	fi
done
echo
echo "Fertig. Beim nächsten Start: Ghost-Menü (FEDORA LINUX · WINDOWS · LOAD GAME · OPTIONS · QUIT GAME),"
echo "nach FEDORA LINUX der animierte Ladebildschirm."
