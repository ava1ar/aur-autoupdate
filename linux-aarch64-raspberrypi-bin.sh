#!/bin/bash

# get Pushover token/user/url values from command line
TOKEN=$1
USER=$2
URL=$3

# Kernel repo URL
KERNEL_REPO_URL=https://github.com/sakaki-/bcmrpi3-kernel.git
# AUR repo URL
AUR_REPO_URL=ssh://aur@aur.archlinux.org/linux-aarch64-raspberrypi-bin.git

# function to run command, check exit code and exit with error code and message if exit code is not 0
function run_and_check_status {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        send_notification "FAILED" "script failed ($1)!"
        exit $status
    fi
    return $status
}

# function to send notification via Pushover (if configured) and print the message
send_notification() {
    echo $2 >&2
    if [[ -z "${TOKEN}" || -z ${USER} ]]; then
        echo "No Pushover token/user specified, no notification will be send!"
    else
	    curl -s --form-string "token=${TOKEN}" \
            --form-string "user=${USER}" \
            --form-string "title=linux-aarch64-raspberrypi-bin" \
            --form-string "url=${URL}" \
            --form-string "url_title=Build log" \
            --form-string message="[$1] $2" \
            https://api.pushover.net/1/messages.json
    fi
}

# Cleanup previous repository location
rm -rf linux-aarch64-raspberrypi-bin

# Clone the PKGBUILD repo from AUR 
run_and_check_status git clone ${AUR_REPO_URL}

# Changedir to the PKGBUILD repo directory
cd linux-aarch64-raspberrypi-bin

# Get current version from PKGBUILD
CURRENT=$(cat PKGBUILD | grep -m1 "pkgver=" | cut -f2 -d"=" | tr -d ' ')

# Check ${CURRENT} value not empty
if [[ -z "${CURRENT}" ]]; then
  send_notification FAILED "Failed to get current version number from the PKGBUILD!"
  exit 1
fi

echo "Current PKGBUILD version is: "${CURRENT}

# Get latest version from the GitHub
run_and_check_status git clone ${KERNEL_REPO_URL}
cd bcmrpi3-kernel/
LATEST=$(git describe --abbrev=0)
cd ../

# Check ${LATEST} value not empty
if [[ -z "${LATEST}" ]]; then
  send_notification FAILED "Failed to get latest version number from the GitHub!"
  exit 1
fi

echo "Latest upstream version is: "${LATEST}

if [[ "${CURRENT}" == "${LATEST}" ]]; then
  send_notification PASSED "No new version available!"
  exit 0
fi

# Obtain latest version download URL from the GitHub
DOWNLOAD_URL=$(curl --silent ${LATEST_RELEASE_URL} | grep '"browser_download_url":' | sed -E 's/.*"([^"]+)".*/\1/')

# Check ${DOWNLOAD_URL} value not empty
if [[ -z "${DOWNLOAD_URL}" ]]; then
  send_notification FAILED "Failed to get latest version download URL from the GitHub!"
  exit 1
fi

echo "New version download URL: "${DOWNLOAD_URL}
run_and_check_status curl --silent --location --output download ${DOWNLOAD_URL}

# Calculate newe version checksum
CHECKSUM=$(sha1sum ./download | cut -f1 -d' ')
echo "New version checksum: "${CHECKSUM}
rm -f ./download

# Patch PKGBUILD
run_and_check_status sed -i "s/pkgver=.*/pkgver=${LATEST}/1; s/pkgrel=.*/pkgrel=1/1; s/sha1sums=(.*/sha1sums=('${CHECKSUM}'/1" ./PKGBUILD

# Generate .SRCINFO
run_and_check_status ../mksrcinfo

# Commit changes to the git
run_and_check_status git config --local user.email "mail@ava1ar.me"
run_and_check_status git config --local user.name "ava1ar's autoupdate bot"
run_and_check_status git add PKGBUILD .SRCINFO
run_and_check_status git commit -m "Updated to ${LATEST}"
run_and_check_status git push origin master
send_notification PASSED "$(git log -n1 --pretty=format:"%s")"

cd .. && rm -rf ./linux-aarch64-raspberrypi-bin
