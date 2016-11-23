#!/usr/bin/env bash
# Script that is run during Vagrant provision to set up the development environment.

# Make non-zero exit codes & other errors fatal.
set -euo pipefail

SRC_DIR="$HOME/treeherder"
VENV_DIR="$HOME/venv"
ELASTICSEARCH_VERSION="2.3.5"

export PATH="$VENV_DIR/bin:$PATH"
# Suppress prompts during apt-get invocations.
export DEBIAN_FRONTEND=noninteractive
# Speeds up pip invocations and reduces output spam.
export PIP_DISABLE_PIP_VERSION_CHECK='True'

cd "$SRC_DIR"

if [[ ! -f /etc/apt/sources.list.d/fkrull-deadsnakes-python2_7-trusty.list ]]; then
    echo '-----> Adding third party PPA for a newer Python 2.7 than the distro package'
    sudo add-apt-repository -y ppa:fkrull/deadsnakes-python2.7 2>&1
fi

echo '-----> Installing/updating packages'
sudo -E apt-get -yqq update
# g++ is required by Brotli
# git is just to improve the UX of the Vagrant environment
# libmemcached-dev and zlib1g-dev are required by pylibmc
# openjdk-7-jre-headless is required by Elasticsearch
# python-dev is required by mysqlclient
sudo -E apt-get -yqq install --no-install-recommends \
    g++ \
    git \
    libmemcached-dev \
    memcached \
    mysql-server-5.6 \
    openjdk-7-jre-headless \
    python2.7 \
    python2.7-dev \
    rabbitmq-server \
    varnish \
    zlib1g-dev

if [[ "$(dpkg-query --show --showformat='${Version}' elasticsearch 2>&1)" != "$ELASTICSEARCH_VERSION" ]]; then
    echo '-----> Installing Elasticsearch'
    ELASTICSEARCH_URL="https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/$ELASTICSEARCH_VERSION/elasticsearch-$ELASTICSEARCH_VERSION.deb"
    curl -sSf -o /tmp/elasticsearch.deb "$ELASTICSEARCH_URL"
    sudo dpkg -i /tmp/elasticsearch.deb
    sudo update-rc.d elasticsearch defaults 95 10
    sudo service elasticsearch start
fi

echo '-----> Configuring MySQL'
if ! cmp -s vagrant/mysql.cnf /etc/mysql/conf.d/treeherder.cnf; then
    sudo cp vagrant/mysql.cnf /etc/mysql/conf.d/treeherder.cnf
    sudo service mysql restart
fi
# The default `root@localhost` grant only allows loopback interface connections.
mysql -u root -e 'GRANT ALL PRIVILEGES ON *.* to root@"%"'
mysql -u root -e 'CREATE DATABASE IF NOT EXISTS treeherder'

echo '-----> Configuring Varnish'
sudo cp vagrant/varnish.vcl /etc/varnish/default.vcl
sudo sed -i '/^DAEMON_OPTS=\"-a :6081* / s/6081/80/' /etc/default/varnish
sudo service varnish reload

if [[ ! -f /usr/local/bin/pip ]]; then
    echo '-----> Installing pip'
    curl -sSf https://bootstrap.pypa.io/get-pip.py | sudo -H python -
fi

if [[ ! -f /usr/local/bin/virtualenv ]]; then
    echo '-----> Installing virtualenv'
    sudo -H pip install virtualenv==15.0.1
fi

if [[ ! -d "$VENV_DIR" ]]; then
    echo '-----> Creating virtualenv'
    virtualenv "$VENV_DIR"
fi

./bin/vendor-libmysqlclient.sh "$VENV_DIR"

echo '-----> Running pip install'
pip install --require-hashes -r requirements/common.txt -r requirements/dev.txt

echo '-----> Configuring user profile and environment variables'
ln -sf "$SRC_DIR/vagrant/.profile" "$HOME/.profile"
sudo ln -sf "$SRC_DIR/vagrant/env.sh" /etc/profile.d/treeherder.sh
