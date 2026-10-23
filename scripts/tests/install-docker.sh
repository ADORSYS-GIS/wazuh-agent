#!/bin/bash

set -ex

export TZ=Europe/Berlin
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y curl sudo gnupg2 nano less apt-transport-https lsb-release systemd systemd-sysv dbus

curl https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | WAZUH_MANAGER=single-cluster.dev.wazuh.adorsys.team bash