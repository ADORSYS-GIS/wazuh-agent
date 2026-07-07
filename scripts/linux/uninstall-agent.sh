#!/bin/sh

set -eu

# Repository ref
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.8.1'}
WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"refs/tags/v${WAZUH_AGENT_REPO_VERSION}"}

# Download utils.sh from repository
# Create a secure temporary directory for utilities
UTILS_TMP=$(mktemp -d)
trap 'rm -rf "$UTILS_TMP"' EXIT
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/shared/utils.sh" -o "$UTILS_TMP/utils.sh"; then
    echo "Failed to download utils.sh"
    exit 1
fi

# Function to calculate SHA256 (cross-platform bootstrap)
calculate_sha256_bootstrap() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
    return 0
}

# Download checksums and verify utils.sh integrity BEFORE sourcing it
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" -o "$UTILS_TMP/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi
CHECKSUMS_FILE="$UTILS_TMP/checksums.sha256"

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# Source utils.sh only after verification
. "$UTILS_TMP/utils.sh"

# ==============================================================================
# Default Configuration
# ==============================================================================
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
WOPS_VERSION=${WOPS_VERSION:-"0.4.3"}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-"0.4.1"}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-"0.2.1"}
WAZUH_AGENT_STATUS_VERSION=${WAZUH_AGENT_STATUS_VERSION:-"0.5.1"}

# Repo ref variables for components
WAZUH_CERT_OAUTH2_REPO_REF=${WAZUH_CERT_OAUTH2_REPO_REF:-"refs/tags/v$WOPS_VERSION"}
WAZUH_YARA_REPO_REF=${WAZUH_YARA_REPO_REF:-"refs/tags/v$WAZUH_YARA_VERSION"}
WAZUH_SNORT_REPO_REF=${WAZUH_SNORT_REPO_REF:-"main"}
WAZUH_SURICATA_REPO_REF=${WAZUH_SURICATA_REPO_REF:-"refs/tags/v$WAZUH_SURICATA_VERSION"}
WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"main"}
WAZUH_AGENT_STATUS_REPO_REF=${WAZUH_AGENT_STATUS_REPO_REF:-"refs/tags/v$WAZUH_AGENT_STATUS_VERSION"}

# Uninstall choice variables
UNINSTALL_TRIVY="FALSE"
UNINSTALL_NETBIRD="FALSE"
UNINSTALL_VELOCIRAPTOR="FALSE"

LINUX_SCRIPT_PATH="scripts/linux/uninstall.sh"
TMP_FOLDER="$(mktemp -d)"

# ==============================================================================
# Helper Functions
# ==============================================================================

cleanup() {
    # Remove temporary folder
    if [ -d "$TMP_FOLDER" ]; then
        rm -rf "$TMP_FOLDER"
    fi
}
trap cleanup EXIT

# Help function to display usage
help_message() {
    printf "%b\n" "${BOLD}Wazuh Agent Comprehensive Uninstallation Script${NORMAL}"
    printf "\n"
    printf "%b\n" "${BOLD}DESCRIPTION:${NORMAL}"
    printf "%s\n" "  This script automates the full removal of a Wazuh agent and its integrations."
    printf "%s\n" "  It uninstalls core components automatically and will also uninstall Snort and Suricata NIDS engines if they are installed."
    printf "\n"
    printf "%b\n" "  ${BLUE}CORE COMPONENTS (Always Uninstalled):${NORMAL}"
    printf "%s\n" "    - Wazuh Agent"
    printf "%s\n" "    - Wazuh Agent Status"
    printf "%s\n" "    - Yara Integration"
    printf "%s\n" "    - Snort (if installed)"
    printf "%s\n" "    - Suricata (if installed)"
    printf "\n"
    printf "%b\n" "  ${YELLOW}CONFIGURABLE COMPONENTS (User Choice):${NORMAL}"
    printf "%s\n" "    You can optionally include a vulnerability scanner and a VPN/mesh client."
    printf "\n"
    printf "%b\n" "${BOLD}USAGE:${NORMAL}"
    printf "%s\n" "  ./uninstall-agent.sh [-t] [-b] [-v] [-h]"
    printf "\n"
    printf "%b\n" "${BOLD}OPTIONS:${NORMAL}"
    printf "%b\n" "  ${YELLOW}-t${NORMAL}         Optionally uninstall ${BOLD}Trivy${NORMAL}."
    printf "%b\n" "  ${YELLOW}-b${NORMAL}         Optionally uninstall ${BOLD}NetBird${NORMAL} (VPN/mesh-network client)."
    printf "%b\n" "  ${YELLOW}-v${NORMAL}         Optionally uninstall ${BOLD}Velociraptor${NORMAL} client."
    printf "%b\n" "  ${YELLOW}-h${NORMAL}         Display this help message and exit."
    printf "\n"
    printf "%b\n" "${BOLD}EXAMPLES:${NORMAL}"
    printf "%s\n" "  # Uninstall all core components + Trivy:"
    printf "%s\n" "  ./uninstall-agent.sh -t"
    printf "%s\n" "  # Uninstall all core components + NetBird:"
    printf "%s\n" "  ./uninstall-agent.sh -b"
    printf "%s\n" "  # Uninstall all core components + Velociraptor:"
    printf "%s\n" "  ./uninstall-agent.sh -v"
    printf "\n"
}

# Only -t, -b, -v and -h options remain
while getopts "tbvh" opt; do
    case ${opt} in
        t)
            UNINSTALL_TRIVY="TRUE"
            ;;
        b)
            UNINSTALL_NETBIRD="TRUE"
            ;;
        v)
            UNINSTALL_VELOCIRAPTOR="TRUE"
            ;;
        h)
            help_message
            exit 0
            ;;
        \?)
            error_message "Invalid option: -$OPTARG" >&2
            help_message
            exit 1
            ;;
        *)
            error_message "Unexpected option state: $opt" >&2
            help_message
            exit 1
            ;;
    esac
done

# ==============================================================================
# Main Uninstallation Logic
# ==============================================================================

info_message "Starting uninstallation. Using temporary directory: \"$TMP_FOLDER\""

# Step 0: Download all uninstall scripts
info_message "Downloading all uninstall scripts..."
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/${LINUX_SCRIPT_PATH}" "$TMP_FOLDER/uninstall-wazuh-agent.sh" "${LINUX_SCRIPT_PATH}" "Wazuh agent uninstall script" "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256"
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/${WAZUH_AGENT_STATUS_REPO_REF}/${LINUX_SCRIPT_PATH}" "$TMP_FOLDER/uninstall-wazuh-agent-status.sh" "${LINUX_SCRIPT_PATH}" "Wazuh Agent Status uninstall script" "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/${WAZUH_AGENT_STATUS_REPO_REF}/checksums.sha256"
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/${WAZUH_YARA_REPO_REF}/${LINUX_SCRIPT_PATH}" "$TMP_FOLDER/uninstall-yara.sh" "${LINUX_SCRIPT_PATH}" "Yara uninstall script" "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/${WAZUH_YARA_REPO_REF}/checksums.sha256"

# Always download both NIDS uninstallers
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/${WAZUH_SURICATA_REPO_REF}/${LINUX_SCRIPT_PATH}" "$TMP_FOLDER/uninstall-suricata.sh" "${LINUX_SCRIPT_PATH}" "Suricata uninstall script" "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/${WAZUH_SURICATA_REPO_REF}/checksums.sha256"
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/${WAZUH_SNORT_REPO_REF}/${LINUX_SCRIPT_PATH}" "$TMP_FOLDER/uninstall-snort.sh" "${LINUX_SCRIPT_PATH}" "Snort uninstall script" "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/${WAZUH_SNORT_REPO_REF}/checksums.sha256"

if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/${WAZUH_TRIVY_REPO_REF}/${LINUX_SCRIPT_PATH}" "$TMP_FOLDER/uninstall-trivy.sh" "${LINUX_SCRIPT_PATH}" "Trivy uninstall script" "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/${WAZUH_TRIVY_REPO_REF}/checksums.sha256"
fi

# Step 1: Uninstall wazuh-agent-status
print_step 1 "Uninstalling wazuh-agent-status..."
if ! (bash "$TMP_FOLDER/uninstall-wazuh-agent-status.sh") 2>&1; then
    error_exit "Failed to uninstall 'wazuh-agent-status'"
fi

# Step 2: Uninstall yara
print_step 2 "Uninstalling yara..."
if ! (bash "$TMP_FOLDER/uninstall-yara.sh") 2>&1; then
    error_exit "Failed to uninstall 'yara'"
fi

# Step 3: Uninstall IDS engines if present
if command_exists suricata; then
    print_step 3 "Uninstalling suricata..."
    if ! (bash "$TMP_FOLDER/uninstall-suricata.sh") 2>&1; then
        error_exit "Failed to uninstall 'suricata'"
    fi
fi

if command_exists snort; then
    print_step 3 "Uninstalling snort..."
    if ! (bash "$TMP_FOLDER/uninstall-snort.sh") 2>&1; then
        error_exit "Failed to uninstall 'snort'"
    fi
fi

# Step 4: Uninstall Trivy if the flag is set
if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    print_step 4 "Uninstalling trivy..."
    if ! (bash "$TMP_FOLDER/uninstall-trivy.sh") 2>&1; then
        error_exit "Failed to uninstall 'trivy'"
    fi
fi

# Step 5: Remove Docker listener virtual environment
VENV_DIR="${VENV_DIR:-/opt/wazuh-docker-env}"
if [ -d "$VENV_DIR" ]; then
    print_step 5 "Removing Docker listener virtual environment..."
    maybe_sudo rm -rf "$VENV_DIR"
    info_message "Docker listener virtual environment removed."
else
    info_message "No Docker listener virtual environment found. Skipping."
fi

# Step 6: Uninstall NetBird if the flag is set
if [ "$UNINSTALL_NETBIRD" = "TRUE" ]; then
    print_step 6 "Uninstalling NetBird..."
    if command_exists netbird; then
        # Stop and remove the daemon via NetBird's own service CLI
        maybe_sudo netbird service stop || warn_message "netbird service stop failed; continuing"
        maybe_sudo netbird service uninstall || warn_message "netbird service uninstall failed; continuing"

        # Detect package manager (inline; utils.sh has no detect_distro)
        if [ -f /etc/debian_version ]; then
            maybe_sudo apt-get remove --purge -y netbird netbird-ui || warn_message "apt netbird remove failed; continuing"
            maybe_sudo rm -f /etc/apt/sources.list.d/netbird.list
            maybe_sudo rm -f /usr/share/keyrings/netbird-archive-keyring.gpg
        elif [ -f /etc/redhat-release ]; then
            if command_exists dnf; then
                maybe_sudo dnf remove -y netbird netbird-ui || warn_message "dnf netbird remove failed; continuing"
            else
                maybe_sudo yum remove -y netbird netbird-ui || warn_message "yum netbird remove failed; continuing"
            fi
            maybe_sudo rm -f /etc/yum.repos.d/netbird.repo
        elif [ -f /etc/SuSE-release ] || [ -d /etc/zypp/repos.d ]; then
            maybe_sudo zypper rm -y netbird netbird-ui || warn_message "zypper netbird remove failed; continuing"
            maybe_sudo zypper removerepo netbird || warn_message "zypper removerepo netbird failed; continuing"
        else
            warn_message "Unsupported distro for NetBird package removal; removing binary if present"
            maybe_sudo rm -f /usr/bin/netbird /usr/bin/netbird-ui
        fi
        success_message "NetBird uninstalled."
    else
        info_message "NetBird not found; skipping."
    fi
fi

# Step 7: Uninstall Velociraptor if the flag is set
if [ "$UNINSTALL_VELOCIRAPTOR" = "TRUE" ]; then
    print_step 7 "Uninstalling Velociraptor..."
    vr_service_file="/etc/systemd/system/velociraptor_client.service"

    # Stop and disable the service if it exists
    if maybe_sudo systemctl cat velociraptor_client >/dev/null 2>&1; then
        maybe_sudo systemctl stop velociraptor_client || warn_message "Failed to stop velociraptor_client service; continuing"
        maybe_sudo systemctl disable velociraptor_client || warn_message "Failed to disable velociraptor_client service; continuing"
    fi

    # Remove the systemd unit file
    if [ -f "$vr_service_file" ]; then
        maybe_sudo rm -f "$vr_service_file"
        maybe_sudo systemctl daemon-reload
        info_message "Velociraptor service file removed."
    fi

    # Remove config directory
    if [ -d "/etc/velociraptor" ]; then
        maybe_sudo rm -rf /etc/velociraptor
        info_message "Velociraptor config directory removed."
    fi

    # Remove binary directory
    if [ -d "/opt/velociraptor" ]; then
        maybe_sudo rm -rf /opt/velociraptor
        info_message "Velociraptor binary directory removed."
    else
        info_message "Velociraptor not found. Skipping."
    fi
    success_message "Velociraptor uninstalled."
fi

# Step 8: Uninstall Wazuh agent
print_step 8 "Uninstalling Wazuh agent..."
if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-wazuh-agent.sh") 2>&1; then
    error_exit "Failed to uninstall wazuh-agent"
fi

success_message "Uninstallation completed successfully."
