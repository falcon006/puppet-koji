class koji::database (
  $dbhost               = undef,
  $dbpass               = undef,
  $need_initdb          = 'true',
  $kojidir              = '/mnt/koji',
  $kojiversion          = undef
) {
  Exec {
    path => "/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
  }

  package { ['postgresql-server',
             'postgresql-contrib']:
    ensure => installed,
  }

  user { 'koji':
    ensure     => present,
    comment    => 'Koji role account for Koji DB',
    managehome => true,
    groups     => 'postgres',
    system     => true,
    require    => Package['postgresql-server'],
  }

  file { '/var/lib/pgsql/data/pg_hba.conf':
    ensure  => present,
    content => template('koji/postgres/pg_hba.conf.erb'),
    owner   => 'postgres',
    group   => 'postgres',
    require => [Package['postgresql-server'],
                Exec['initdb']],
    notify  => Service['postgresql'],
    mode    => '0600'
  }

  service { "postgresql":
    ensure => running,
    enable => true
  }

  exec { "initdb" :
    command => "postgresql-setup initdb",
    unless  => "/usr/bin/test -f /var/lib/pgsql/data/PG_VERSION",
    onlyif  => $need_initdb,
    require => [Package["postgresql-server"]]
  }

  exec { "init_koji_db":
    user    => "postgres",
    command => "createuser -R -S -D koji &&
                createdb -O koji koji",
    unless  => "psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='koji'\" | grep 1 2>/dev/null ",
    path    => "/bin:/sbin:/usr/sbin:/usr/bin",
    require => [Package["postgresql-server"],
                Exec["initdb"],
                Service['postgresql']]
  }

  exec { "init_koji_schema" :
    user => 'koji',
    command => "psql koji < /usr/share/doc/koji-`rpm -qa --queryformat \"%{NAME}: %{VERSION}\\n\" | awk '/koji:/{print \$NF}'`/docs/schema.sql &&
                psql koji -tAc \"insert into users (name, status, usertype) values ('kojiadmin', 0, 0)\" &&
                psql koji -tAc \"insert into user_perms (user_id, perm_id, creator_id) values (1,1,1)\"",
    unless => "psql koji -tAc \"select * from users where name = 'kojiadmin'\"",
    require => [Exec["init_koji_db"]],
  }

#  cron { 'truncate_sessions_db':
#    ensure  => present,
#    command => 'DELETE FROM sessions WHERE update_time < now() - \'1 day\'::interval;',
#    user    => 'koji',
#    minute  => 0,
#    hour    => 23,
#    weekday => 5,
#    require => User['koji']
#  }

  # Do a full vacuum daily at midnight
  cron { 'vacuum_db':
    ensure  => present,
    command => 'vacuumdb -fza > /dev/null',
    user    => 'postgres',
    minute  => 0,
    hour    => 0,
    weekday => 6,
    require => Package["postgresql-server"]
  }

  cron { 'backup_koji_db':
    ensure  => present,
    command => 'pg_dump koji | gzip -c -9  > /var/lib/pgsql/backups/koji_db_`date +\\%d\\%m\\%Y`.sql.gz',
    minute  => 0,
    hour    => 5,
    user    => 'koji',
    require => User['koji']
  }

  cron { 'prune_koji_db_backups':
    ensure  => present,
    command => 'find /var/lib/pgsql/backups -mtime 14 -exec rm -f {} \\;',
    minute  => 30,
    hour    => 0,
    user    => 'koji',
    require => User['koji']
  }
}

