#!/usr/bin/env bash
# Script that is run during Vagrant provision to set up the development environment.

# Make non-zero exit codes & other errors fatal.
set -euo pipefail

SRC_DIR="$HOME/treeherder"

# Suppress prompts during apt-get invocations.
export DEBIAN_FRONTEND=noninteractive

cd "$SRC_DIR"

if [[ ! -f /etc/apt/sources.list.d/fkrull-deadsnakes-python2_7-trusty.list ]]; then
    echo '-----> Adding third party PPA for a newer Python 2.7 than the distro package'
    sudo add-apt-repository -y ppa:fkrull/deadsnakes-python2.7 2>&1
fi

echo '-----> Installing/updating packages'
sudo -E apt-get -yqq update
sudo -E apt-get -yqq install --no-install-recommends \
    mysql-server-5.6

echo '-----> Configuring MySQL'
if ! cmp -s vagrant/mysql.cnf /etc/mysql/conf.d/treeherder.cnf; then
    sudo cp vagrant/mysql.cnf /etc/mysql/conf.d/treeherder.cnf
    sudo service mysql restart
fi
# The default `root@localhost` grant only allows loopback interface connections.
mysql -u root -e 'GRANT ALL PRIVILEGES ON *.* to root@"%"'
mysql -u root -e 'CREATE DATABASE IF NOT EXISTS treeherder'
