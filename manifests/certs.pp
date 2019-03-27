class koji::certs (
    $username = undef,
    $autocerts = false,
    $users    = [ 'yourkojibuilder1.example.com' ,
                  'kojiadmin' ],
    $cert     = '/etc/koji/user.pem',
    $ca       = '/etc/koji/koji_ca.crt',
    $serverca = '/etc/koji/koji_serverca.crt',
    $caname   = 'koji',
    $cn       = 'koji.example.com',
    $subj     = undef
) {

  package { ['openssl',
             'openssl-libs',
            ]:
    ensure => installed,
  }->

  file { '/etc/pki/koji':
    ensure  => directory,
    recurse => true,
    source  => 'puppet:///modules/koji/pki',
    owner   => 'root',
    group   => 'root'
  }->

  exec { 'initcakey':
    cwd => '/etc/pki/koji',
    path => '/bin:/sbin/:/usr/bin:/usr/sbin',
    command => 'openssl genrsa -out private/koji_ca_cert.key 2048',
    unless  => "/usr/bin/test -f /etc/pki/koji/private/koji_ca_cert.key",
  }
  ->
  exec { "initca" :
    cwd => '/etc/pki/koji',
    path => '/bin:/sbin/:/usr/bin:/usr/sbin',
    command => "touch index.txt; echo 01 > serial;openssl req -config ssl.cnf -new -batch -x509 -subj \"${subj}/CN=${cn}\" -days 3650 -key private/koji_ca_cert.key -set_serial 01 -out koji_ca_cert.crt -extensions v3_ca",
    unless  => "/usr/bin/test -f /etc/pki/koji/koji_ca_cert.crt",
    require => [Package["openssl"]]
  }->

  koji::userkeys{ $users:
    caname => $caname,
    subj => $subj
  }
}

# Note $title and $user seperation. Want to make unique files with
# same CN type.
define koji::userkeys ($caname, $subj, $user = $title) {
  exec { "koji_key_${title}":
    cwd => '/etc/pki/koji',
    path => '/bin:/sbin/:/usr/bin:/usr/sbin',
    command => "openssl genrsa -out private/${title}.key 2048;openssl req -config ssl.cnf -new -nodes -out certs/${title}.csr -key private/${title}.key  -subj \"${subj}/CN=${user}\";openssl ca -batch -config ssl.cnf -keyfile private/${caname}_ca_cert.key  -cert ${caname}_ca_cert.crt -out certs/${title}.crt -outdir certs -infiles certs/${title}.csr; cat certs/${title}.crt private/${title}.key > ${title}.pem",
    unless  => "/usr/bin/test -f /etc/pki/koji/private/${title}.key",
    require => [Package["openssl"]]
  }
}
 
