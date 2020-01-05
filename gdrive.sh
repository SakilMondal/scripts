#!/usr/bin/env bash

# Copyright (C) Harsh Shandilya <msfjarvis@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

trap 'rm /tmp/gdrive 2>/dev/null' INT TERM EXIT
# Source common functions
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
echo ${SCRIPT_DIR}
source "${SCRIPT_DIR}"/common

# Install standard packages.
echoText "Installing necessary packages"
sudo apt install -y aria2 jq

function check_and_install_gdrive() {
    local GDRIVE ARTIFACT_NAME
    ARTIFACT_NAME="gdrive-linux-x64"
    echoText "Checking and installing gdrive"
    GDRIVE="$(command -v gdrive)"
    if [ -z "${GDRIVE}" ]; then
        install_gdrive
    else
        INSTALLED_VERSION="$(gdrive version | grep gdrive | awk '{print $2}')"
        LATEST_VERSION="$(get_latest_release gdrive-org/gdrive)"
        if [ "${INSTALLED_VERSION}" != "${LATEST_VERSION}" ]; then
            reportWarning "Outdated version of gdrive detected, upgrading"
            install_gdrive
        else
            reportWarning "gdrive ${INSTALLED_VERSION} is already installed!"
        fi
    fi
}

function install_gdrive() {
    aria2c "$(get_release_assets gdrive-org/gdrive | grep ${ARTIFACT_NAME})" --allow-overwrite=true -d ~/bin -o gdrive
    chmod +x ~/bin/gdrive
    sudo install ~/bin/gdrive /usr/local/bin/gdrive
    rm ~/bin/gdrive
    gdrive list
}

check_and_install_gdrive
