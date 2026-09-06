# ── Virtualization ────────────────────────────────────────────────────────────

# Adapted from Bazzite's setup-virtualization recipe:
# Set up libvirt, VFIO kernel args, USB hot plugging helpers, and SELinux ISO access
[group("virtualization")]
setup-virtualization ACTION="":
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    if [[ $(id -u) -eq 0 ]]; then
        echo "Please do not run this command as root."
        exit 1
    fi

    on_valve_hardware() {
        command -v /usr/libexec/hwsupport/valve-hardware >/dev/null 2>&1 &&
            /usr/libexec/hwsupport/valve-hardware
    }

    ensure_libvirtd() {
        if ! systemctl is-enabled --quiet libvirtd.service 2>/dev/null; then
            echo "Enabling libvirtd..."
            sudo systemctl enable --now libvirtd
        elif ! systemctl is-active --quiet libvirtd.service 2>/dev/null; then
            echo "Starting libvirtd..."
            sudo systemctl start libvirtd
        fi
    }

    ensure_swtpm_state() {
        echo "Making sure swtpm state exists..."
        sudo mkdir -p /var/lib/swtpm-localca
        sudo chown tss:tss /var/lib/swtpm-localca 2>/dev/null || sudo chown tss /var/lib/swtpm-localca
        sudo restorecon -Rv /var/lib/libvirt /var/log/libvirt /var/lib/swtpm-localca 2>/dev/null || true
    }

    grant_iso_acl() {
        if command -v setfacl >/dev/null 2>&1; then
            echo "Giving qemu read access to ISO files in $HOME..."
            sudo setfacl -m u:qemu:rx "$HOME" || true
        fi
    }

    cpu_vendor_karg() {
        local cpu_vendor
        cpu_vendor="$(awk -F': ' '/vendor_id/ { print $2; exit }' /proc/cpuinfo)"
        case "$cpu_vendor" in
            AuthenticAMD) echo "amd_iommu=on" ;;
            GenuineIntel) echo "intel_iommu=on" ;;
            *) return 1 ;;
        esac
    }

    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust setup-virtualization <option>"
        echo "  virt-on     Enable virtualization kernel args and libvirtd"
        echo "  virt-off    Disable virtualization kernel args and libvirtd"
        echo "  group       Add $USER to the libvirt group"
        echo "  vfio-on     Enable VFIO-related kernel args"
        echo "  vfio-off    Disable VFIO-related kernel args"
        echo "  usbhp-on    Enable SPICE USB hot plugging rule"
        echo "  usbhp-off   Disable SPICE USB hot plugging rule"
        echo "  iso-dir     Set up an ISO directory with SELinux labels for VM access"
        exit 0
    elif [[ -z "$OPTION" ]]; then
        echo "${bold}Virtualization Setup${normal}"
        echo "Caracal already ships the virtualization packages in the base image."
        OPTION=$(Choose \
            "Enable virtualization" \
            "Disable virtualization" \
            "Add $USER to libvirt group" \
            "Enable VFIO drivers" \
            "Disable VFIO drivers" \
            "Enable USB hot plugging" \
            "Disable USB hot plugging" \
            "Set up ISO directory for VM access" \
        )
    fi

    if on_valve_hardware; then
        echo "${red}${b}WARNING${n}: Virtualization and VFIO are not well supported on Steam Deck-class hardware."
    fi

    if [[ "${OPTION,,}" =~ (^enable[[:space:]]virtualization|virt-on) ]]; then
        ensure_libvirtd
        ensure_swtpm_state
        grant_iso_acl
        rpm-ostree kargs \
            --append-if-missing="kvm.ignore_msrs=1" \
            --append-if-missing="kvm.report_ignored_msrs=0"
        echo "Virtualization enabled. Reboot if kernel args changed."

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]virtualization|virt-off) ]]; then
        if systemctl is-enabled --quiet libvirtd.service 2>/dev/null ||
            systemctl is-active --quiet libvirtd.service 2>/dev/null; then
            echo "Disabling libvirtd..."
            sudo systemctl disable --now libvirtd || true
        fi
        rpm-ostree kargs \
            --delete-if-present="kvm.ignore_msrs=1" \
            --delete-if-present="kvm.report_ignored_msrs=0"
        echo "Virtualization disabled. Base packages remain installed; reboot if kernel args changed."

    elif [[ "${OPTION,,}" =~ group ]]; then
        if ! getent group libvirt >/dev/null 2>&1; then
            echo "libvirt group is missing."
            exit 1
        fi
        sudo usermod -aG libvirt "$USER"
        echo "Added $USER to libvirt. Log out and back in for group membership to apply."

    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]vfio|vfio-on) ]]; then
        if on_valve_hardware; then
            echo "IOMMU/VFIO is not supported on this hardware."
            exit 0
        fi

        ensure_libvirtd
        vendor_karg="$(cpu_vendor_karg)" || {
            echo "Failed to determine CPU vendor."
            exit 1
        }

        rpm-ostree initramfs --enable
        rpm-ostree kargs \
            --append-if-missing="kvm.ignore_msrs=1" \
            --append-if-missing="kvm.report_ignored_msrs=0" \
            --append-if-missing="${vendor_karg}" \
            --append-if-missing="iommu=pt" \
            --append-if-missing="rd.driver.pre=vfio-pci" \
            --append-if-missing="vfio_pci.disable_vga=1"

        echo "VFIO kernel args queued for next boot."
        echo 'Add passthrough device IDs separately with: rpm-ostree kargs --append-if-missing="vfio_pci.ids=xxxx:yyyy,xxxx:zzzz"'
        echo "Reboot after enabling VFIO."

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]vfio|vfio-off) ]]; then
        echo "Make sure any VFIO-backed VMs are not set to autostart before continuing."
        CONFIRM=$(Choose Cancel Continue)
        if [[ "$CONFIRM" != "Continue" ]]; then
            exit 0
        fi

        vfio_ids="$(rpm-ostree kargs | tr ' ' '\n' | grep '^vfio_pci.ids=' || true)"
        rpm_ostree_args=(
            --delete-if-present="iommu=pt"
            --delete-if-present="iommu=on"
            --delete-if-present="amd_iommu=on"
            --delete-if-present="intel_iommu=on"
            --delete-if-present="rd.driver.pre=vfio-pci"
            --delete-if-present="vfio_pci.disable_vga=1"
            --delete-if-present="vfio_pci.disable_vga=0"
        )
        if [[ -n "$vfio_ids" ]]; then
            rpm_ostree_args+=(--delete-if-present="$vfio_ids")
        fi

        sudo rm -f /etc/dracut.conf.d/vfio.conf
        rpm-ostree kargs "${rpm_ostree_args[@]}"
        echo "VFIO kernel args removed. Reboot to apply."

    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]usb|usbhp-on) ]]; then
        echo "Adding udev rule for USB hot plugging..."
        printf '%s\n' 'ACTION=="add", SUBSYSTEM=="usb", TAG+="uaccess"' |
            sudo tee /etc/udev/rules.d/72-usbhp.rules >/dev/null
        sudo udevadm control --reload || true
        echo "USB hot plugging enabled."

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]usb|usbhp-off) ]]; then
        sudo rm -f /etc/udev/rules.d/72-usbhp.rules
        sudo udevadm control --reload || true
        echo "USB hot plugging disabled."

    elif [[ "${OPTION,,}" =~ (^set[[:space:]]up[[:space:]]iso|iso-dir) ]]; then
        echo "Set up an ISO directory with proper SELinux labels for VM access."
        echo "ISOs in this directory will be readable by QEMU without manual fixes."
        read -r -e -p "ISO directory path [default: \$HOME/ISOs]: " iso_path
        iso_path="${iso_path:-$HOME/ISOs}"
        if [[ ! -d "$iso_path" ]]; then
            mkdir -p "$iso_path"
            echo "Created $iso_path"
        fi
        if command -v semanage >/dev/null 2>&1; then
            echo "Setting SELinux context virt_content_t on $iso_path..."
            sudo semanage fcontext -a -t virt_content_t "${iso_path}(/.*)?" 2>/dev/null || \
                echo "SELinux file context rule already exists, updating..."
            sudo restorecon -Rv "$iso_path"
        else
            echo "semanage not available — falling back to chcon."
            echo "This context will not survive a full SELinux relabel."
            sudo chcon -Rt svirt_home_t "$iso_path" 2>/dev/null || \
                sudo chcon -Rt virt_content_t "$iso_path"
        fi
        if command -v setfacl >/dev/null 2>&1; then
            sudo setfacl -m u:qemu:rx "$iso_path"
            echo "ACL grants qemu read access to $iso_path."
        fi
        echo "ISO directory ready. Copy or move your ISO files into $iso_path,"
        echo "then add them to your VM through virt-manager."

    else
        echo "Unknown option: $OPTION"
        echo "Run 'ujust setup-virtualization help' for usage."
        exit 1
    fi

# One-shot VM environment setup: libvirt, kernel args, ISO directory, groups
[group("virtualization")]
setup-vm-env:
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    if [[ $(id -u) -eq 0 ]]; then
        echo "Please do not run this command as root."
        exit 1
    fi

    echo "${bold}Caracal VM Environment Setup${normal}"
    echo "This will configure everything needed for VM management in one go."
    echo ""

    # Step 1: libvirt group
    echo "⟦1/5⟧ Adding $USER to libvirt group..."
    if ! getent group libvirt >/dev/null 2>&1; then
        echo "libvirt group is missing — creating it."
        sudo groupadd --system libvirt
    fi
    sudo usermod -aG libvirt "$USER"

    # Step 2: enable libvirtd
    echo "⟦2/5⟧ Enabling and starting libvirtd..."
    if ! systemctl is-enabled --quiet libvirtd.service 2>/dev/null; then
        sudo systemctl enable --now libvirtd
    elif ! systemctl is-active --quiet libvirtd.service 2>/dev/null; then
        sudo systemctl start libvirtd
    else
        echo "  libvirtd already running."
    fi

    # Step 3: swtpm state
    echo "⟦3/5⟧ Ensuring swtpm state..."
    sudo mkdir -p /var/lib/swtpm-localca
    sudo chown tss:tss /var/lib/swtpm-localca 2>/dev/null || sudo chown tss /var/lib/swtpm-localca
    sudo restorecon -Rv /var/lib/libvirt /var/log/libvirt /var/lib/swtpm-localca 2>/dev/null || true

    # Step 4: kernel args
    echo "⟦4/5⟧ Setting virtualization kernel args..."
    rpm-ostree kargs \
        --append-if-missing="kvm.ignore_msrs=1" \
        --append-if-missing="kvm.report_ignored_msrs=0"

    # Step 5: ISO directory with SELinux labels
    echo "⟦5/5⟧ Setting up ISO directory..."
    iso_path="$HOME/ISOs"
    if [[ ! -d "$iso_path" ]]; then
        mkdir -p "$iso_path"
        echo "  Created $iso_path"
    fi
    if command -v semanage >/dev/null 2>&1; then
        sudo semanage fcontext -a -t virt_content_t "${iso_path}(/.*)?" 2>/dev/null || \
            echo "  SELinux rule already exists."
        sudo restorecon -Rv "$iso_path"
    else
        sudo chcon -Rt svirt_home_t "$iso_path" 2>/dev/null || \
            sudo chcon -Rt virt_content_t "$iso_path"
    fi
    if command -v setfacl >/dev/null 2>&1; then
        sudo setfacl -m u:qemu:rx "$iso_path" 2>/dev/null || true
    fi
    echo "  ISO directory: $iso_path"

    # Activate tmpfiles.d config immediately
    if [[ -f /usr/lib/tmpfiles.d/caracal-libvirt-workarounds.conf ]]; then
        sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/caracal-libvirt-workarounds.conf 2>/dev/null || true
    fi

    echo ""
    echo "${green}${b}Done.${n} VM environment is ready."
    echo "Copy your ISO files into ${iso_path} and use virt-manager to create VMs."
    echo "Reboot if kernel args changed, or log out and back in for group membership to apply."