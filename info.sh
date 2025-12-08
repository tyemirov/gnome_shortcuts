#!/bin/bash
# Obsidian AppImage Diagnostic Script for KDE/GNOME by ChatGPT

echo "System Information:"
# Detect OS (pretty name) and desktop session details
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$PRETTY_NAME"
else
    OS="$(lsb_release -sd 2>/dev/null)"
fi
# Detect desktop environment
DE="unknown"
if echo "${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}" | grep -qi "KDE"; then
    # KDE/Plasma session
    plasma_ver=$(plasmashell --version 2>/dev/null)
    # plasmashell --version outputs e.g. "plasmashell 5.27.4"
    DE="KDE Plasma"
    [ -n "$plasma_ver" ] && DE="$DE ${plasma_ver#plasmashell }"
elif echo "${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}${XDG_SESSION_DESKTOP:-}" | grep -qi "GNOME"; then
    # GNOME session
    gnome_ver=$(gnome-shell --version 2>/dev/null)   # e.g. "GNOME Shell 44.1"
    DE="GNOME"
    [ -n "$gnome_ver" ] && DE="$DE ${gnome_ver#GNOME Shell }"
elif [ -n "$XDG_SESSION_DESKTOP" ]; then
    DE="$XDG_SESSION_DESKTOP"
elif [ -n "$XDG_CURRENT_DESKTOP" ]; then
    # If multiple values (e.g. "ubuntu:GNOME"), take first
    DE="${XDG_CURRENT_DESKTOP%%:*}"
else
    DE="${DESKTOP_SESSION:-unknown}"
fi
# Detect display server (Wayland/X11)
if [ "${XDG_SESSION_TYPE}" = "wayland" ]; then
    SESSION_TYPE="Wayland"
elif [ "${XDG_SESSION_TYPE}" = "x11" ]; then
    SESSION_TYPE="X11"
else
    # Fallback detection
    if [ -n "$WAYLAND_DISPLAY" ]; then
        SESSION_TYPE="Wayland"
    elif [ -n "$DISPLAY" ]; then
        SESSION_TYPE="X11"
    else
        SESSION_TYPE="unknown"
    fi
fi
echo "- OS: ${OS:-Unknown}"
echo "- Desktop environment: $DE"
echo "- Session type (display): $SESSION_TYPE"

echo
echo "FUSE & AppImage Support:"
# Check libfuse2, libfuse3, and AppImageLauncher packages
for pkg in libfuse2 libfuse3 appimagelauncher; do
    if dpkg -s "$pkg" &>/dev/null; then
        ver=$(dpkg -s "$pkg" | awk -F': ' '/^Version:/{print $2}')
        echo "- $pkg: installed (version $ver)"
    else
        echo "- $pkg: NOT installed"
    fi
done
# Check fuse group membership
if id -nG "$USER" 2>/dev/null | grep -qw fuse; then
    echo "- User '$USER' is in the 'fuse' group"
else
    echo "- User '$USER' is NOT in the 'fuse' group"
fi
# Check if fuse kernel module is loaded or available
if grep -qw fuse /proc/modules; then
    echo "- FUSE kernel module: loaded"
elif [ -e /dev/fuse ]; then
    echo "- FUSE support: /dev/fuse present (module might be built-in or auto-loadable)"
else
    echo "- FUSE kernel module: NOT loaded (no /dev/fuse device)"
fi

echo
echo "Obsidian AppImage Mount Check:"
echo ">> Please launch the Obsidian AppImage now, then press Enter here once it has attempted to start."
echo "   (If it fails immediately, run it with '--no-sandbox' to keep it open for this check.)"
read -r _   # wait for user
# Find Obsidian's mount point in /tmp (if still mounted)
mount_line=$(mount | grep -E "/tmp/.mount_Obsidi")
if [ -n "$mount_line" ]; then
    # Extract mount details
    mnt_point=$(echo "$mount_line" | awk '{print $3}')
    fs_type=$(echo "$mount_line" | awk '{print $5}')
    if echo "$mount_line" | grep -q " type fuse"; then
        method="FUSE (user-space mount)"
    elif echo "$mount_line" | grep -q "/dev/loop"; then
        method="kernel loop device (squashfs)"
    else
        method="unknown method"
    fi
    echo "- Obsidian AppImage is mounted at $mnt_point (filesystem type: $fs_type, via $method)"
else
    echo "- No Obsidian mount found. (It may have mounted and unmounted quickly if the app failed to start.)"
fi

echo
echo "Sandbox and Launch Info:"
# Check kernel settings for unprivileged user namespaces (relevant to Chrome sandbox)
if [ -r /proc/sys/kernel/unprivileged_userns_clone ]; then
    echo "- kernel.unprivileged_userns_clone = $(cat /proc/sys/kernel/unprivileged_userns_clone)"
fi
if [ -r /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]; then
    echo "- kernel.apparmor_restrict_unprivileged_userns = $(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)"
fi
# Check environment variable for Chrome sandbox development override
if [ -n "${CHROME_DEVEL_SANDBOX}" ]; then
    echo "- CHROME_DEVEL_SANDBOX is set to: $CHROME_DEVEL_SANDBOX"
else
    echo "- CHROME_DEVEL_SANDBOX is not set"
fi
# Detect if Obsidian is running and whether --no-sandbox was used
obs_process=$(pgrep -af "Obsidian")
if [ -n "$obs_process" ]; then
    if echo "$obs_process" | grep -q "\-\-no-sandbox"; then
        echo "- Obsidian process is running with '--no-sandbox' (sandbox disabled)"
    else
        echo "- Obsidian process is running (no --no-sandbox flag detected)"
    fi
else
    echo "- Obsidian process is not running"
fi

echo
echo "==== End of Diagnostics ===="
echo "Please copy and paste the above output into the support chat or forum thread for analysis."
