class my_postgres {

  if lookup(vagrant){
    notice ("I amm in Vagrant!")
    $extra = {
      pg_hba_conf_defaults => false,
      manage_pg_hba_conf => true,
    }
    $extra_config = {
      # config_entries => { # NOTE - it worked with this, but is it needed?
        timezone => 'UTC',
        listen_addresses => '*',
      # }
    }
    postgresql::server::pg_hba_rule {'local-ps':
      type => local,
      database => all,
      user => postgres,
      auth_method => peer,
      description => "Database administrative login by Unix domain socket",
      order => 1,
    }
    postgresql::server::pg_hba_rule {'local-all':
      type => local,
      database => all,
      user => all,
      auth_method => md5,
      description => '"local" is for Unix domain socket connections only"',
      order => 2,
    }
    postgresql::server::pg_hba_rule {'host-ip4':
      type => host,
      database => all,
      user => all,
      address => '127.0.0.1/32',
      auth_method => md5,
      description => 'IPv4 local connections',
      order => 3,
    }
    postgresql::server::pg_hba_rule {'host-ip6':
      type => host,
      database => all,
      user => all,
      address => '::1/128',
      auth_method => md5,
      description => 'IPv6 local connections',
      order => 4,
    }
    postgresql::server::pg_hba_rule {'host-all':
      type => host,
      database => all,
      user => all,
      address => 'all',
      auth_method => md5,
      description => 'host all connections',
      order => 5,
    }

    postgresql::server::role { 'submitty_dbuser':
      password_hash => postgresql::postgresql_password('submitty_dbuser', 'submitty_dbuser'),
      superuser => true,
      createdb => true,
      createrole => true,
    }
    postgresql::server::role { 'vagrant':
      password_hash => postgresql::postgresql_password('vagrant', 'vagrant'),
      superuser => true,
      createdb => true,
      createrole => true,
    }

  } else {
    $extra = {}
    $extra_config = {}
  }


class { 'postgresql::globals':
  manage_package_repo => true,
  version             => '12', # NOTE it should be 12.8
  encoding => 'UTF-8',
  locale   => 'en_US.UTF-8',
  * => $extra,
}

class { 'postgresql::server':
  service_ensure => 'running',
  * => $extra_config,
}

}
