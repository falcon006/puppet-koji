# manage the koji-hub function of koji. This class requires apache with mod_ssl
# mod_wsgi and mod_python as well as a postgres database
#
# Some postgres work needs to be manually done for this to work properly. The
# following needs to be run manually:
# root@localhost$ su - postgres
# postgres@localhost$ createuser koji
# Shall the new role be a superuser? (y/n) n
# Shall the new role be allowed to create databases? (y/n) n
# Shall the new role be allowed to create more new roles? (y/n) n
# postgres@localhost$ createdb -O koji koji
# postgres@localhost$ psql -c "alter user koji with encrypted password '$dbpass';"
# postgres@localhost$ logout
# root@localhost$ su - koji
# koji@localhost$ psql koji koji < /usr/share/doc/koji*/docs/schema.sql
# koji@localhost$ logout
# root@localhost$ service postgresql reload
# root@localhost$ su - koji
# koji@localhost$ psql
# koji=> insert into users (name, status, usertype) values ('root', 0, 0);
# koji=> select * from users;
### Use the output above to find the user ID number ###
# koji=> insert into user_perms (user_id, perm_id, creator_id) values (<user ID>, 1, <user ID>);
# koji=> \q
# koji@localhost$ logout
# root@localhost$ service postgresql restart
#
# For more information, see:
# https://fedoraproject.org/wiki/Koji/ServerHowTo#Koji_Hub
#
# To leverage external repos for mock environment builds, the following commands were used:
# user@localhost:~/tmp $ koji add-tag centos-6
# user@localhost:~/tmp $ koji add-tag --parent centos-6 --arches "x86_64" centos-6-build
# user@localhost:~/tmp $ koji add-external-repo -t centos-6-build centos-6-external-repo http://mirror.example.com/centos/6/os/\$arch/
# Created external repo 1
# Added external repo centos-6-external-repo to tag centos-6-build (priority 5)
# user@localhost:~/tmp $ koji add-target centos-6 centos-6-build centos-6
# user@localhost:~/tmp $ koji add-group centos-6-build build
# user@localhost:~/tmp $ koji add-group centos-6-build srpm-build
# user@localhost:~/tmp $ koji add-group-pkg centos-6-build build bash bzip2 centos-release coreutils cpio diffutils findutils gawk gcc gcc-c++ grep gzip make patch redhat-rpm-config sed shadow-utils tar unzip util-linux-ng which xz texinfo rpm-build
# user@localhost:~/tmp $ koji regen-repo centos-6-build
#
# After the regen-repo is completed, you should be able to successfully build packages.

class koji::hub (
    $dbname               = 'koji',
    $dbuser               = 'koji',
    $dbhost               = undef,
    $dbpass               = undef,
    $kojidir              = '/mnt/koji',
    $authprincipal        = undef,
    $authkeytab           = undef,
    $proxyprincipals      = undef,
    $hostprincipalformat  = undef,
    $dnusernamecomponent  = 'CN',
    $proxydn              = '/C=US/ST=Washington/L=Seattle/O=Example/OU=Foo/CN=bar/emailAddress=foo@example.com',
    $logincreateuser      = undef,
    $kojiweburl           = undef,
    $emaildomain          = 'example.com',
    $notifyonsuccess      = true,
    $disablenotifications = undef,
    $enablemaven          = undef,
    $enablewin            = undef,
    $pluginpath           = undef,
    $plugins              = undef,
    $kojidebug            = undef,
    $kojitraceback        = undef,
    $serveroffline        = undef,
    $offlinemessage       = undef,
    $lockout              = undef
) {
    include koji::httpd

    package { ['koji-hub',
               'koji',
               'koji-utils']:
        ensure => present
    }

    file { ["${kojidir}/packages",
            "${kojidir}/repos",
            "${kojidir}/work",
            "${kojidir}/scratch"]:
        ensure => directory,
        owner  => 'apache',
        group  => 'apache',
        mode   => undef,
    }

    file { '/etc/koji-hub/hub.conf':
        ensure  => present,
        content => template('koji/hub/hub.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644'
    }

    file { '/etc/httpd/conf.d/kojihub.conf':
        ensure  => present,
        content => template('koji/hub/kojihub_httpd.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['httpd']
    }

    file { '/etc/koji-gc/koji-gc.conf':
        ensure  => present,
        content => template('koji/hub/koji-gc.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['koji-utils']
    }

    file { '/usr/local/bin/sign_unsigned.py':
        ensure  => present,
        content => template('koji/hub/sign_unsigned.py.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755'
    }

    file { '/etc/pki/pkgsigner':
        ensure  => directory,
        source  => 'puppet:///modules/koji/gnupg',
        recurse => true,
        owner   => 'root',
        group   => 'root',
        mode    => '0770'
    }

    # Daily pruning of old builds
    cron { 'koji_gc':
        ensure  => present,
        command => '/usr/sbin/koji-gc --purge --no-mail',
        minute  => 0,
        hour    => 10,
        require => [
            File['/etc/koji-gc/koji-gc.conf'],
            Package['koji-utils']
        ]
    }
}
