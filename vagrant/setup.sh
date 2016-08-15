#!/usr/bin/env bash
# Script that is run during Vagrant provision to set up the development environment.

# Make non-zero exit codes & other errors fatal.
set -euo pipefail

if [[ ! -f /etc/apt/sources.list.d/fkrull-deadsnakes-python2_7-trusty.list ]]; then
    echo '-----> Adding third party PPA for a newer Python 2.7 than the distro package'
    sudo add-apt-repository -y ppa:fkrull/deadsnakes-python2.7 2>&1
fi

echo "-----> Updating package list"
sudo -E apt-get -yqq update
