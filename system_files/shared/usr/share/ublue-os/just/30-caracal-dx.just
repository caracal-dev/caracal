# ── Developer Experience ──────────────────────────────────────────────────────

# Add the current user to common DX groups for Docker, Incus, libvirt, and serial devices
[group("system")]
dx-group:
    #!/usr/bin/pkexec bash
    set -euo pipefail

    append_group() {
        local group_name="$1"

        if getent group "$group_name" >/dev/null 2>&1; then
            return 0
        fi

        if grep -q "^${group_name}:" /usr/lib/group 2>/dev/null; then
            grep "^${group_name}:" /usr/lib/group >> /etc/group
        else
            groupadd -r "$group_name"
        fi
    }

    target_user="{{ `id -un` }}"
    groups_add=(docker incus-admin libvirt dialout)

    for group_name in "${groups_add[@]}"; do
        append_group "$group_name"
        usermod -aG "$group_name" "$target_user"
    done

    echo "Added ${target_user} to: ${groups_add[*]}"
    echo "Reboot, or log out and back in, before using Docker, Incus, libvirt, or serial devices."