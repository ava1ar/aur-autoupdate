function run_and_check_status {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
	exit $status
    fi
    return $status
}

# Cleanup previous repository location
rm -rf linux-aarch64-raspberrypi-bin

# Clone the PKGBUILD repo from AUR 
run_and_check_status git clone ssh://aur@aur.archlinux.org/linux-aarch64-raspberrypi-bin.git

# Changedir to the PKGBUILD repo directory
cd linux-aarch64-raspberrypi-bin

# Get current version from PKGBUILD
CURRENT=$(cat PKGBUILD | grep -m1 "pkgver=" | cut -f2 -d"=" | tr -d ' ')

# Check ${CURRENT} value not empty
if [[ -z "${CURRENT}" ]]; then
  echo "Failed to get current version from the PKGBUILD!" >&2
  exit 1
fi

echo "Current PKGBUILD version is: "${CURRENT}

# Get latest version from the GitHub
LATEST=$(curl --silent https://api.github.com/repos/sakaki-/bcmrpi3-kernel/releases | grep -m1 tag_name | cut -f2 -d":" | tr -d '", ')

# Check ${LATEST} value not empty
if [[ -z "${LATEST}" ]]; then
  echo "Failed to get latest version number from the GitHub!" >&2
  exit 1
fi

echo "Latest upstream version is: "${LATEST}

if [[ "${CURRENT}" == "${LATEST}" ]]; then
  echo "No new version available!"
  exit 0
fi

# Obtain latest version download URL from the GitHub
DOWNLOAD_URL=$(curl --silent https://api.github.com/repos/sakaki-/bcmrpi3-kernel/releases | grep -m1 browser_download_url | cut -f4 -d"\"" | tr -d '", ')

# Check ${DOWNLOAD_URL} value not empty
if [[ -z "${DOWNLOAD_URL}" ]]; then
  echo "Failed to get latest version download URL from the GitHub!" >&2
  exit 1
fi

echo "New version download URL: "${DOWNLOAD_URL}
run_and_check_status curl --silent -o download ${DOWNLOAD_URL}

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

cd .. && rm -rf ./linux-aarch64-raspberrypi-bin
