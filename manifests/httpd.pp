class koji::httpd {
  package { ['httpd',
             'mod_ssl',
             'mod_wsgi']:
    ensure => installed,
  } 

  service { 'httpd':
    ensure => running,
    enable => true
  }
}
