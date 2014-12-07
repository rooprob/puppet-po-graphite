# == Class: graphite::install::source
#
# This class installs graphite packages via source
#
# === Parameters
#
# None.
#
class graphite::install::source inherits graphite::params {

  $whisper_dl_url = "http://github.com/graphite-project/whisper/archive/${graphite::whisper_version}.tar.gz"
  $whisper_dl_loc = "${graphite::build_dir}/whisper-${graphite::whisper_version}.tar.gz"

  $webapp_dl_url  = "http://github.com/graphite-project/graphite-web/archive/${graphite::graphite_version}.tar.gz"
  $webapp_dl_loc  = "${graphite::build_dir}/graphite-web-${graphite::graphite_version}.tar.gz"

  $carbon_dl_url  = "https://github.com/graphite-project/carbon/archive/${graphite::carbon_version}.tar.gz"
  $carbon_dl_loc  = "${graphite::build_dir}/carbon-${graphite::carbon_version}.tar.gz"

  file { $graphite::install_dir:
    ensure  => directory,
    owner   => 'carbon',
    group   => 'carbon',
    mode    => '0755',
  }

# DUP defined in config.pp
#  file { $graphite::storage_dir:
#    ensure => directory,
#    owner  => 'www-data',
#    group  => 'www-data',
#    mode   => '0755',
#    before => [
#      Exec['install_carbon'],
#      Exec['install_graphite'],
#    ]
#  }

  package{['python-virtualenv', 'libcairo2-dev','python-pip','python-dev']:
    ensure => present
  }

  exec { 'graphite_venv':
    umask   => '022',
    command => '/usr/bin/virtualenv /opt/graphite',
    creates => '/opt/graphite/bin/activate',
    require => Package['python-virtualenv'],
  }

  wget::fetch { 'wget_whisper':
    source      => $whisper_dl_url,
    destination => $whisper_dl_loc,
    timeout     => 0,
    verbose     => false,
    require     => File[$::graphite::install_dir],
  }->
  exec { 'unpack_whisper':
    cwd         => $graphite::build_dir,
    command     => "/bin/tar -xzvf ${whisper_dl_loc}",
  }->
  # whisper goes to the /usr/bin by default. No overrides possible
  exec { 'install_whisper':
    umask   => 022,
    cwd     => "${graphite::build_dir}/whisper-${graphite::whisper_version}",
    command => '/opt/graphite/bin/python setup.py install',
    require => Exec['graphite_venv'],
  }

  wget::fetch { 'wget_graphite':
    source      => $webapp_dl_url,
    destination => $webapp_dl_loc,
    timeout     => 0,
    verbose     => false,
    require     => File[$::graphite::install_dir],
  }->
  exec { 'unpack_graphite':
    cwd         => $graphite::build_dir,
    command     => "/bin/tar -xzvf ${webapp_dl_loc}",
  }->
  exec { 'install_ez_setup':
    umask   => 022,
    command => "/usr/bin/curl https://bootstrap.pypa.io/ez_setup.py | /opt/graphite/bin/python",
    require => Exec['graphite_venv'],
  }->
  exec { 'install_graphite_prereqs':
    umask   => 022,
    cwd     => "${graphite::build_dir}/graphite-web-${graphite::graphite_version}",
    command => "/opt/graphite/bin/pip install -r requirements.txt",
    require => [
      Package['libcairo2-dev'],
      Package['python-dev'],
      Package['python-pip'],
    ]
  }->
  exec { 'install_graphite':
    umask   => 022,
    cwd     => "${graphite::build_dir}/graphite-web-${graphite::graphite_version}",
    command => "/opt/graphite/bin/python setup.py install --prefix=${graphite::install_dir} --install-lib=${graphite::install_dir}/webapp",
  }

  wget::fetch { 'wget_carbon':
    source      => $carbon_dl_url,
    destination => $carbon_dl_loc,
    timeout     => 0,
    verbose     => false,
    require     => File[$::graphite::install_dir],
  }->
  exec { 'unpack_carbon':
    cwd         => $graphite::build_dir,
    command     => "/bin/tar -xzvf ${carbon_dl_loc}",
  }->
  exec { 'install_carbon_prereqs':
    umask   => 022,
    cwd     => "${graphite::build_dir}/carbon-${graphite::carbon_version}",
    command => "/opt/graphite/bin/pip install -r requirements.txt",
    require => [
      Exec['graphite_venv'],
    ]
  }->
  exec { 'install_carbon':
    umask   => 022,
    cwd     => "${graphite::build_dir}/carbon-${graphite::carbon_version}",
    command => "/opt/graphite/bin/python setup.py install --prefix=${::graphite::install_dir} --install-lib=${::graphite::install_dir}/lib",
  }

  # DUP: partially repeated from config.pp
  file { [
      "${graphite::install_dir}/bin",
      "${graphite::install_dir}/conf",
      "${graphite::install_dir}/examples",
      "${graphite::install_dir}/lib",
      "${graphite::install_dir}/webapp",
      "${graphite::install_dir}/webapp/graphite",
      ]:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  exec { 'set_storage_permissions':
    command => "/bin/chown -R carbon:carbon ${graphite::storage_dir}",
    require => Exec['install_carbon'],
  }
}
