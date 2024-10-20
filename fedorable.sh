#!/bin/bash

# Set PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Dialog dimensions
HEIGHT=20
WIDTH=90
CHOICE_HEIGHT=15

# Titles and messages
BACKTITLE="Fedorable - A Fedora Post Install Setup Util - By Smittix - https://lsass.co.uk"
TITLE="Please Make a Selection"
MENU="Please Choose one of the following options:"

# Other variables
OH_MY_ZSH_URL="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
LOG_FILE="setup_log.txt"

# Log function
log_action() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a $LOG_FILE
}

# Check for dialog installation
if ! rpm -q dialog &>/dev/null; then
    sudo dnf install -y dialog || { log_action "Failed to install dialog. Exiting."; exit 1; }
    log_action "Installed dialog."
fi

# Options for the menu
OPTIONS=(
    1 "Enable RPM Fusion - Enables the RPM Fusion repos for your specific version"
    2 "Update Firmware - If your system supports FW update delivery"
    3 "Speed up DNF - Sets max parallel downloads to 10 + Fastest server"
    4 "Enable Flatpak - Enables the Flatpak repo and installs packages located in flatpak-packages.txt"
    5 "Install Software - Installs software located in dnf-packages.txt"
    6 "Install Oh-My-ZSH - Installs Oh-My-ZSH & Starship Prompt"
    7 "Install Extras - Themes, Fonts, and Codecs"
    8 "Install Nvidia - Install akmod Nvidia drivers"
    9 "Enable Virtualization - KVM/QEMU  + VirtManager"
    10 "Enable TLP"
    11 "Install OpenRazer + Polychromatic"
    12 "Install VSCode"
    13 "Install RustDesk"
    14 "Btrfs snapshot in Grub + dnf plugin snapper"
    15 "Install Docker"
    16 "Quit"
)

# Function to handle RPM Fusion setup
enable_rpm_fusion() {
    echo "Enabling RPM Fusion"
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf upgrade --refresh -y
    sudo dnf group update -y core
    sudo dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted dnf-plugins-core
}

# Function to update firmware
update_firmware() {
    echo "Updating System Firmware"
    sudo fwupdmgr get-devices
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update
}

# Function to speed up DNF
speed_up_dnf() {
    echo "Speeding Up DNF"
    echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
    echo 'fastestmirror=True' | sudo tee -a /etc/dnf/dnf.conf
}

# Function to enable Flatpak
enable_flatpak() {
    echo "Enabling Flatpak"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak update -y
    if [ -f flatpak-install.sh ]; then
        source flatpak-install.sh
    else
        log_action "flatpak-install.sh not found"
    fi
}

# Function to install software
install_software() {
    echo "Installing Software"
    
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

    if [ -f dnf-packages.txt ]; then
        sudo dnf install -y $(cat dnf-packages.txt)
        sudo dnf remove -y dragon
    else
        log_action "dnf-packages.txt not found"
    fi
}

# Function to install Oh-My-Zsh and Starship
install_oh_my_zsh() {
    echo "Installing Oh-My-Zsh with Starship"
    sudo dnf install -y zsh curl util-linux-user
    sh -c "$(curl -fsSL $OH_MY_ZSH_URL)" "" --unattended
    chsh -s "$(which zsh)"
    curl -sS https://starship.rs/install.sh | sh
    echo 'eval "$(starship init zsh)"' >> ~/.zshrc
}

# Function to install extras
install_extras() {
    echo "Installing Extras"
    sudo dnf groupupdate -y sound-and-video
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    sudo dnf install -y libdvdcss
    sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,ugly-\*,base} gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel ffmpeg gstreamer-ffmpeg
    sudo dnf install -y lame\* --exclude=lame-devel
    sudo dnf group upgrade -y --with-optional Multimedia
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
    sudo dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
    sudo dnf update -y
}

# Function to install Nvidia drivers
install_nvidia() {
    echo "Installing Nvidia Driver Akmod-Nvidia"
    sudo dnf install -y akmod-nvidia
}

enable_virt() {
    sudo dnf install -y @virtualization
    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt $(whoami)
    sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
    sudo sed -i 's/#unix_sock_ro_perms = "0777"/unix_sock_ro_perms = "0777"/' /etc/libvirt/libvirtd.conf
    sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf
}

enable_tlp() {
    sudo systemctl enable tlp.service
    sudo systemctl start tlp.service
}

install_openrazer() {
    sudo dnf install -y kernel-devel
    sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/hardware:/razer/Fedora_$(rpm -E %fedora)/hardware:razer.repo
    sudo dnf install -y openrazer-meta
    sudo dnf install -y polychromatic
    sudo gpasswd -a $(whoami) plugdev
}

install_vscode() {
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    sudo dnf install -y code
}

install_rustdesk() {
    rustdesk_latest_release=$(curl --silent "https://api.github.com/repos/rustdesk/rustdesk/releases/latest")
    rustdesk_download_url=$(echo "$rustdesk_latest_release" | grep -Eo 'https://[^\"]+x86_64\.rpm' | uniq)
    sudo dnf install -y $rustdesk_download_url
    sudo systemctl enable --now rustdesk
}

install_snapshot_grub() {
    # Install make and snapper dnf plugin
    sudo dnf install -y make python3-dnf-plugin-snapper

    # Clone the grub-btrfs repository
    git clone https://github.com/Antynea/grub-btrfs.git
    cd grub-btrfs

    # Edit the grub-btrfs configuration
    sed -i 's/^#GRUB_BTRFS_SUBMENUNAME.*/GRUB_BTRFS_SUBMENUNAME="Fedora Linux snapshots"/' config
    sed -i 's/^#GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS.*/GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"/' config
    sed -i 's/^#GRUB_BTRFS_GRUB_DIRNAME.*/GRUB_BTRFS_GRUB_DIRNAME="\/boot\/grub2"/' config
    sed -i 's/^#GRUB_BTRFS_BOOT_DIRNAME.*/GRUB_BTRFS_BOOT_DIRNAME="\/boot"/' config
    sed -i 's/^#GRUB_BTRFS_MKCONFIG.*/GRUB_BTRFS_MKCONFIG=\/usr\/sbin\/grub2-mkconfig/' config
    sed -i 's/^#GRUB_BTRFS_SCRIPT_CHECK.*/GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check/' config

    # Install grub-btrfs and update GRUB configuration
    sudo make install
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    cd ..
    sudo rm -rf grub-btrfs

    # Edit /etc/fstab to optimize BTRFS mount options
    sudo sed -i 's/subvol=root,compress=zstd:1/subvol=root,compress=zstd:1,defaults,noatime,discard=async/' /etc/fstab
    sudo sed -i 's/subvol=home,compress=zstd:1/subvol=home,compress=zstd:1,defaults,noatime,discard=async/' /etc/fstab

    # Install inotify-tools
    sudo dnf install -y inotify-tools

    # Enable and start grub-btrfsd service
    sudo systemctl enable --now grub-btrfsd
}

install_docker() {
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $(whoami)
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    sudo yum install -y nvidia-container-toolkit
    sudo systemctl enable --now docker
}

# Main loop
while true; do
    CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --nocancel \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

    clear
    case $CHOICE in
        1) enable_rpm_fusion ;;
        2) update_firmware ;;
        3) speed_up_dnf ;;
        4) enable_flatpak ;;
        5) install_software ;;
        6) install_oh_my_zsh ;;
        7) install_extras ;;
        8) install_nvidia ;;
        9) enable_virt ;;
        10) enable_tlp ;;
        11) install_openrazer ;;
        12) install_vscode ;;
        13) install_rustdesk ;;
        14) install_snapshot_grub ;;
        15) install_docker ;;
        16) log_action "User chose to quit the script."; exit 0 ;;
        *) log_action "Invalid option selected: $CHOICE";;
    esac
done
