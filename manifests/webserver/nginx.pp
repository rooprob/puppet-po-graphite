# == Class: graphite::webserver::nginx
#
# This class configures nginx to talk to graphite/carbon/whisper and SHOULD
# NOT be called directly.
#
# === Parameters
#
# None.
#
class graphite::webserver::nginx inherits graphite::params {

  Exec { path => '/bin:/usr/bin:/usr/sbin' }

  #include graphite::webserver::gunicorn
  include graphite::webserver::uwsgi

  if $::osfamily != 'debian' {
    fail("nginx-based graphite is not supported on ${::operatingsystem} (only supported on Debian)")
  }

  # we need a nginx with gunicorn for python support

  package {
    'nginx':
      ensure => 'installed',
      before => Exec['Chown graphite for web user'],
      notify => Exec['Chown graphite for web user'];
  }

  file { '/etc/nginx/sites-enabled/default':
    ensure  => absent,
    require => Package['nginx'],
    notify  => Service['nginx'];
  }

  service {
    'nginx':
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => Exec['Chown graphite for web user'];
  }

  # Ensure that some directories exist first. This is normally handled by the
  # package, but if we uninstall and reinstall nginx and delete /etc/nginx.
  # By default the package manager won't replace the directory.

  file {
    '/etc/nginx':
      ensure  => directory,
      mode    => '0755',
      require => Package['nginx'];
  }

  # Deploy configfiles

  file {
    '/etc/nginx/conf.d/graphite':
      ensure  => file,
      mode    => '0644',
      content => template('graphite/etc/nginx/conf.d/graphite.erb'),
      require => [
        Exec['Initial django db creation'],
        Exec['Chown graphite for web user']
      ],
      notify  => Service['nginx'];
  }

  # HTTP basic authentication
  $nginx_htpasswd_file_presence = $::graphite::nginx_htpasswd ? {
    undef   => absent,
    default => absent,
  }
  file {
    '/etc/nginx/graphite-htpasswd':
      ensure  => $nginx_htpasswd_file_presence,
      mode    => '0400',
      owner   => $::graphite::params::web_user,
      content => $::graphite::nginx_htpasswd,
      require => Package['nginx'],
      notify  => Service['nginx'];
  }

}