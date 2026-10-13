#!/usr/bin/bash
# ★ 8155 – macht „ghost“ rückgängig (GRUB-Menü + Plymouth-Ladebildschirm, Zustand von vor installieren.sh).
# Als root ausführen:  pkexec ~/.config/hypr/grub-ghost/rueckgaengig.sh > /tmp/ghost.log 2>&1
# Stellt /etc/default/grub, /boot/grub2/grub.cfg und /etc/plymouth/plymouthd.conf aus der ältesten Sicherung
# *.vor-ghost-* wieder her und baut die initramfs neu (wieder mit dem alten Plymouth-Theme)
# (grub.cfg wird bewusst NICHT neu erzeugt – Fedoras 10_linux würde dabei die „options“ der Boot-Einträge umschreiben).
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "Bitte als root ausführen: pkexec $0" >&2; exit 1; }
alt_default=$(ls /etc/default/grub.vor-ghost-* 2> /dev/null | sort | head -1)
alt_cfg=$(ls /boot/grub2/grub.cfg.vor-ghost-* 2> /dev/null | sort | head -1)
[ -n "$alt_default" ] && [ -n "$alt_cfg" ] || { echo "Keine Sicherung *.vor-ghost-* gefunden." >&2; exit 1; }

cp -a "$alt_default" /etc/default/grub
cp -a "$alt_cfg" /boot/grub2/grub.cfg
rm -f /etc/grub.d/15_ghost_menu /etc/kernel/install.d/95-ghost-menu.install
chmod +x /etc/grub.d/10_linux /etc/grub.d/30_uefi-firmware
grub2-editenv /boot/grub2/grubenv unset gfxmode
rm -rf /boot/grub2/themes/ghost
echo "GRUB zurück auf: $alt_default + $alt_cfg (Sicherungen bleiben liegen)."

alt_ply=$(ls /etc/plymouth/plymouthd.conf.vor-ghost-* 2> /dev/null | sort | head -1)
if [ -n "$alt_ply" ]; then
	cp -a "$alt_ply" /etc/plymouth/plymouthd.conf
	rm -rf /usr/share/plymouth/themes/ghost
	for k in /boot/vmlinuz-*; do
		kver=${k#/boot/vmlinuz-}
		case "$kver" in 0-rescue-*) continue ;; esac
		[ -d "/lib/modules/$kver" ] || continue
		echo "initramfs $kver …"
		dracut -f "/boot/initramfs-$kver.img" "$kver"
	done
	echo "Plymouth zurück auf: $alt_ply (Paket plymouth-plugin-script bleibt installiert)."
fi
