puppet-koji
===========

Fork from the orginal: https://github.com/drwahl/puppet-koji

Wanted something that really 'bootstrap' itself without too much interaction. The services like database, first user, UI, certs are all automically handled now. This version will get you to a nearly working state of koji. The only bits remain is to add your builder nodes then distribute certs/keys to your users.

Even though the user certs are generated for you. I decided not include the master CA cert. Managing the certs is on you. Makes things a bit more secure, I don't want everyone to use the same keys :P. With that said make sure you back up your certs, keys and database.


## Usage

Step 1:  (optional) Generate your CA cert. After generating your signing key the module will use that to create users, builders and other commincation keys. Follow this guide for more details. https://docs.pagure.org/koji/server_howto/

Check out certs.pp to see what files we expect to be generated. If keys are not generated it will attempt to create new ones.


Step 2: Import the plugin to your Puppetfile :
```puppetfile
mod "puppet-koji",
  :git    => 'https://github.com/falcon006/puppet-koji'
```

Step 3: Update your site.pp. Below is an example.

Using this module you want your .pp config to be defined like so.

**test with puppet 4.x**

### koji service example (single node)

```puppet
node "koji.example.com" {
  # Shared mountpoint between builder and koji server. nfs is nice and simple
  # but there are other methods to solve this.
  class { '::nfs':
    server_enabled => true
  }->
  nfs::server::export{ '/mnt/koji':
    ensure  => 'mounted',
    clients => '10.8.0.0/16(rw,sync,no_subtree_check,no_root_squash)'
  }->
  class { 'koji::certs':
    # This class will automatically setup your certs. But
    # you must initialize your signing certificate.
    # Use this module for builder, admins and users
    users     => [ 'kojibuilder1.example.com',
                   'kojiadmin',
                   'yourteam_alias',
                   'falcon006' ],
    caname    => 'koji',
    cn        => 'koji.example.com',
    subj      => '/C=US/O=barracuda/ST=California/L=San Jose/OU=koji',
  }->
  koji::userkeys { 'kojiweb':
    #special certs for backend communication
    user     => 'koji.example',
    caname   => 'koji',
    subj     => '/C=US/O=barracuda/ST=California/L=San Jose/OU=kojiweb',
  }->
  koji::userkeys { 'kojihub':
    #special certs for backend communication
    user     => 'koji.example.com',
    caname   => 'koji',
    subj     => '/C=US/O=barracuda/ST=California/L=San Jose/OU=kojihub',
  }->
  class { 'koji::hub':
    # build hub after keys are created
    proxydn         => 'CN=koji.scl.cudaops.com,OU=kojiweb,O=barracuda,L=San Jose,ST=California,C=US',
    logincreateuser => 'On',
    emaildomain     => 'example.com',
    kojiweburl      => 'http://koji.example.com/koji',
  }->
  class { 'koji::database': }->
  class { 'koji::web':
    kojihuburl   => 'http://koji.example.com/kojihub',
    kojifilesurl => 'http://koji.example.com/kojifiles',
  }->
  class { 'koji::client':
    server      => 'http://koji.example.com/kojihub',
    weburl      => 'http://koji.example.com/koji',
    topurl      => 'http://koji.example.com/',
    cert        => '/etc/pki/koji/kojiadmin.pem',
    ca          => '/etc/pki/koji/koji_ca_cert.crt',
    serverca    => '/etc/pki/koji/koji_ca_cert.crt',
  }
  # Centos7 7.4 was used to develop this. Packages may vary.
  package { ['perl-libwww-perl','perl-JSON','perl-LWP-Protocol-https']:
              ensure => 'installed',
              provider => 'yum',
           }

}
```
### builder example

```puppet
node /^kojibuilder\d+\.example\.com$/ {
  # file sharing between koji.example.com and kojibuilder.example.com
  class { '::nfs':
    server_enabled => true
  }
  Nfs::Client::Mount <<| |>> {
    ensure => 'mounted'
  }
  class { 'koji::builder':
    server   => 'http://koji.example.com/kojihub',
    topurl   => 'http://koji.example.com/kojifiles',
    ca       => '/etc/kojid/koji_ca_cert.crt',
    serverca => '/etc/kojid/koji_ca_cert.crt',
    cert     => '/etc/kojid/kojibuilder1.example.com.pem',
    smtphost => 'your.smarthost.email.server',
  }
}
```

