#!/data/data/com.termux/files/usr/bin/bash

# Exit on any error
set -e

# Update and upgrade Termux packages
echo "Updating and upgrading Termux packages..."
pkg update -y && pkg upgrade -y

# Install required Termux repositories and packages
echo "Installing required Termux packages..."
pkg install -y x11-repo tur-repo
pkg install -y termux-x11-nightly pulseaudio proot-distro wget git

# Install Arch Linux via proot-distro
echo "Installing Arch Linux..."
proot-distro install archlinux

# Log into Arch Linux and configure it
echo "Configuring Arch Linux environment..."
proot-distro login archlinux -- bash -c '
  # Update Arch Linux package database and system
  pacman -Syu --noconfirm
  pacman -Sy --noconfirm

  # Install XFCE4 desktop environment and sudo
  pacman -S --noconfirm xfce4 xfce4-goodies sudo

  # Create user "focalors" with wheel group for sudo privileges
  if ! id focalors &>/dev/null; then
    useradd -m -G wheel -s /bin/bash focalors
    echo "focalors:focalors" | chpasswd
  fi

  # Configure sudoers file for user "focalors"
  if ! grep -q "focalors ALL=(ALL) ALL" /etc/sudoers; then
    echo "focalors ALL=(ALL) ALL" >> /etc/sudoers
  fi
'

# Create startarchlinux.sh script
echo "Creating startarchlinux.sh script..."
cat > startarchlinux.sh << 'EOL'
#!/data/data/com.termux/files/usr/bin/bash

# Kill open X11 processes
kill -9 $(pgrep -f "termux.x11") 2>/dev/null || true

# Enable PulseAudio over Network
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# Prepare termux-x11 session
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null &

# Wait a bit until termux-x11 gets started.
sleep 3

# Launch Termux X11 main activity
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# Login in PRoot Environment. Do some initialization for PulseAudio, /tmp directory
# and run XFCE4 as user focalors.
# See also: https://github.com/termux/proot-distro
# Argument -- acts as terminator of proot-distro login options processing.
# All arguments behind it would not be treated as options of PRoot Distro.
proot-distro login archlinux --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=${TMPDIR} && su - focalors -c "env DISPLAY=:0 startxfce4"'

exit 0
EOL

# Make startarchlinux.sh executable
chmod +x startarchlinux.sh

# Move startarchlinux.sh to Termux bin directory for easy access
mv startarchlinux.sh /data/data/com.termux/files/usr/bin/
echo "startarchlinux.sh has been created and moved to /data/data/com.termux/files/usr/bin/"

# Kill any existing Termux X11 processes
echo "Terminating existing Termux X11 processes..."
kill -9 $(pgrep -f "termux.x11") 2>/dev/null || true

# Start PulseAudio server
echo "Starting PulseAudio server..."
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# Prepare Termux X11 session
echo "Starting Termux X11..."
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null &

# Wait for Termux X11 to initialize
sleep 3

# Launch Termux X11 main activity
echo "Launching Termux X11 activity..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 1

# Log into Arch Linux and start XFCE4 as user "focalors"
echo "Starting XFCE4 desktop environment..."
proot-distro login archlinux --shared-tmp -- /bin/bash -c \
  'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=${TMPDIR} && su - focalors -c "env DISPLAY=:0 startxfce4"'

# Exit cleanly
exit 0
