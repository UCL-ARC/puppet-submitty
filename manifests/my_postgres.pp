class my_postgres {

  if lookup(vagrant){
    notice ('I amm in Vagrant!')
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
      type        => local,
      database    => all,
      user        => postgres,
      auth_method => peer,
      description => 'Database administrative login by Unix domain socket',
      order       => 1,
    }
    postgresql::server::pg_hba_rule {'local-all':
      type        => local,
      database    => all,
      user        => all,
      auth_method => md5,
      description => '"local" is for Unix domain socket connections only"',
      order       => 2,
    }
    postgresql::server::pg_hba_rule {'host-ip4':
      type        => host,
      database    => all,
      user        => all,
      address     => '127.0.0.1/32',
      auth_method => md5,
      description => 'IPv4 local connections',
      order       => 3,
    }
    postgresql::server::pg_hba_rule {'host-ip6':
      type        => host,
      database    => all,
      user        => all,
      address     => '::1/128',
      auth_method => md5,
      description => 'IPv6 local connections',
      order       => 4,
    }
    postgresql::server::pg_hba_rule {'host-all':
      type        => host,
      database    => all,
      user        => all,
      address     => 'all',
      auth_method => md5,
      description => 'host all connections',
      order       => 5,
    }

    postgresql::server::role { 'vagrant':
      password_hash => postgresql::postgresql_password('vagrant', 'vagrant'),
      superuser     => true,
      createdb      => true,
      createrole    => true,
    }

  } else {
    $extra = {}
    $extra_config = {}
  }

  unless lookup(worker){
    postgresql::server::role { lookup('submitty.db.user'):
      password_hash => postgresql::postgresql_password(lookup('submitty.db.user'), lookup('submitty.db.passwd')),
      superuser     => true,
      createdb      => true,
      createrole    => true,
    }

    postgresql::server::database { 'submitty':
      owner   => lookup('submitty.db.user'),
      require => Postgresql::Server::Role[lookup('submitty.db.user')],
    }
    postgresql::server::schema { 'public':
      owner   => lookup('submitty.db.user'),
      require => Postgresql::Server::Role[lookup('submitty.db.user')],
    }
    # FIXME to pupetize migrator
    # It creates a set of databases, not sure how to check that's done.
    exec {'run_db_migration':
      cwd     => join([lookup('submitty.directories.repository.path'), 'Submitty'], '/'),
      path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      command => 'python3 migration/run_migrator.py -e master -e system migrate --initial > /tmp/puppet_db_migration 2>&1',
      # onlyif  => 'test ! $(su -c "psql -lqt | cut -d \| -f 1 | grep -w submitty || true" postgres)',
      unless  => "su -c \"PGPASSWORD=${lookup('submitty.db.passwd')} psql -U ${lookup('submitty.db.user')} -d submitty -c '\\dt' | cut -d '|' -f 2 | grep -wq courses\" postgres",
      require => [
        Postgresql::Server::Database['submitty'],
        Postgresql::Server::Schema['public'],
        File['submitty_users.json'],
        Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Submitty'], '/')],
        Package['pip_sqlalchemy'],
      ],
    }

    lookup('psql-logger').each | String $key, String $value | {
      file_line { "psql-logger-${key}":
        ensure  => present,
        path    => "/etc/postgresql/${lookup('versions.db.psql')}/main/postgresql.conf",
        line    => "${key} = ${value}",
        match   => "^#*[ tab]*${key}[ tab]+",
        require => [Class['postgresql::globals'],]
      }
    }
  }

class { 'postgresql::globals':
  manage_package_repo => true,
  version             => "${lookup('versions.db.psql')}", # NOTE it should be 12.8
  encoding            => 'UTF-8',
  locale              => 'en_US.UTF-8',
  *                   => $extra,
}

class { 'postgresql::server':
  service_ensure => 'running',
  *              => $extra_config,
}

}
