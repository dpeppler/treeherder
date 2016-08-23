class python {
  # When we're not using Puppet, extract the version from runtime.txt instead.
  $python_version = '2.7.11'
  $python_url = "https://lang-python.s3.amazonaws.com/cedar-14/runtimes/python-${python_version}.tar.gz"

  package{[# Required by mysqlclient.
           "python-dev",
           # Required by pylibmc.
           "libmemcached-dev",
           "zlib1g-dev",
           # Required by Brotli.
           "g++",
           # To improve the UX of the Vagrant environment.
           "git"]:
    ensure => "installed",
  }

  exec { "vendor-python":
    user => "${APP_USER}",
    command => "rm -rf ${VENDOR_DIR} && mkdir -p ${VENDOR_DIR} && curl -sS ${python_url} | tar zx -C ${VENDOR_DIR}",
    unless => "test \"\$(${VENDOR_DIR}/bin/python --version 2>&1)\" = 'Python ${python_version}'",
  }

  exec { "install-pip":
    user => "${APP_USER}",
    command => "curl -sS https://bootstrap.pypa.io/get-pip.py | ${VENDOR_DIR}/bin/python -",
    creates => "${VENDOR_DIR}/bin/pip",
    require => Exec["vendor-python"],
  }

  exec {"vendor-libmysqlclient":
    command => "${PROJ_DIR}/bin/vendor-libmysqlclient.sh ${VENDOR_DIR}",
    require => Exec["install-pip"],
    user => "${APP_USER}",
  }

  exec{"pip-install":
    require => Exec["vendor-libmysqlclient"],
    user => "${APP_USER}",
    cwd => "${PROJ_DIR}",
    command => "pip install --disable-pip-version-check --require-hashes -r requirements/common.txt -r requirements/dev.txt",
    timeout => 1800,
  }

  # Clean up the old virtualenv directory. This can be removed after a few weeks.
  file {"${HOME_DIR}/venv":
   ensure  => absent,
   force   => true,
  }
}
