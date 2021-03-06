class koji::web (
    $sitename     = 'koji',
    $kojitheme    = undef,
    $kojihuburl   = 'http://kojihub.example.com/kojihub',
    $kojifilesurl = 'http://kojiweb.example.com/kojifiles',
    $webprincipal = undef,
    $webkeytab    = undef,
    $webccache    = undef,
    $webcert      = undef,
    $clientca     = undef,
    $kojihubca    = undef,
    $logintimeout = 72,
    $secret       = 'CHANGE_ME',
    $libpath      = '/usr/share/koji-web/lib',
    $kojimount    = '/mnt/koji'
) {
    include koji::httpd

    package { 'koji-web':
        ensure => present
    }

    file { '/etc/kojiweb/web.conf':
        ensure  => present,
        content => template('koji/web/web.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['koji-web'],
        notify  => Service['httpd']
    }

    file { '/etc/httpd/conf.d/kojiweb.conf':
        ensure  => present,
        content => template('koji/web/kojiweb_httpd.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['httpd']
    }
}
