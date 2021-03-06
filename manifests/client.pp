# a class to setup koji for rpm development. assumes that the certs have
# already been created for $username. mutually exclusive with any other
# koji classes. taken from:
# https://fedoraproject.org/wiki/Koji/ServerHowTo#Setting_up_SSL_Certificates_for_authentication
# Hint: we use ssl for authentication

class koji::client (
    $username = undef,
    $server   = 'http://kojihub.example.com/kojihub',
    $weburl   = 'http://kojiweb.example.com/koji',
    $topurl   = 'http://kojiweb.example.com/',
    $cert     = '/etc/koji/user.pem',
    $ca       = '/etc/koji/koji_ca.crt',
    $serverca = '/etc/koji/koji_serverca.crt',
    $caname   = 'koji'
) {
    if ! defined(Package['koji']) {
      package { 'koji':
        ensure => present
      }
    }

#TODO: not exactly secure putting certs here, but it'll do for now
    file { '/etc/koji':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
    }

    file { '/etc/koji.conf':
        ensure  => present,
        content => template('koji/koji.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['koji']
    }
}
