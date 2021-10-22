class submitty_config {

  $submitty_dirs = lookup('submitty.directories', Hash)
  $submitty_dirs.each | String $item, Hash $options | {
    file {$options['path']:
      ensure => directory,
      * => $options,
    }
  }

  ## Submitty data
  $submitty_extra_dirs = lookup('extra_dirs', Hash)
  $submitty_extra_dirs.each | String $item, Hash $options | {
    file {$options['path']:
      ensure => directory,
      * => $options,
    }
  }


  $data_dir = lookup('submitty.directories.data.path')
  $data_dirs = ['instructors'] # TODO What happen with this? what permissions should it have?
  if lookup('worker') {
    $extra_data_dirs = []
  }
  else {
    $extra_data_dirs = []
  }
  file {($data_dirs + $extra_data_dirs).map | $item | {join([$data_dir, $item], '/')}:
    ensure => directory,
    require => File[lookup('submitty.directories.data.path')]
  }

  file {"${data_dir}/instructors/valid":
    ensure => present,
    # FIXME: it still needs the users that are not system users
    content => join(sort(lookup('system_users', Hash, 'hash').map |$key, $value| {$key}), "\n")
  }

  ##############################################################################
  # make the installation setup directory
  ##############################################################################
  file {"setup_install_dir":
    path => join([lookup('submitty.directories.install.path'), '.setup'], '/'),
    ensure => directory,
    owner => 'root',
    group => 'submitty_course_builders',
    mode => '751',
    require => File[lookup('submitty.directories.install.path')],
  }
  ##############################################################################
  # make the installation config directory
  ##############################################################################
  file {"config_install_dir":
    path => join([lookup('submitty.directories.install.path'), 'config'], '/'),
    ensure => directory,
    owner => 'root',
    group => 'submitty_course_builders',
    mode => '755',
    require => File[lookup('submitty.directories.install.path')],
  }

  file { 'submitty_conf.json':
    path => join([lookup('submitty.directories.install.path'), '.setup', 'submitty_conf.json'], '/'),
    ensure  => file,
    owner => 'root',
    mode => '500',
    content => to_json_pretty(lookup('submitty_configuration')),
    require => File["setup_install_dir"],
  }
  ### Create INSTALL_SUBMITTY.sh 700 and
  # FIXME is it needed?

  file { 'email.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'email.json'], '/'),
    ensure  => file,
    owner => 'root',
    group => 'submitty_daemonphp',
    mode => '400',
    content => to_json_pretty(lookup('submitty_email')),
    require => File["config_install_dir"],
  }

  file { 'submitty_admin.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'submitty_admin.json'], '/'),
    ensure  => file,
    owner => 'root',
    group => 'submitty_daemon',
    mode => '400',
    content => to_json_pretty(lookup('submitty_admin')),
    require => File["config_install_dir"],
  }

  file { 'secrets_submitty_php.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'secrets_submitty_php.json'], '/'),
    ensure  => file,
    owner => 'root',
    group => 'submitty_php',
    mode => '440',
    content => to_json_pretty(lookup('submitty_secrets_php')),
    require => File["config_install_dir"],
  }

  file { 'submitty_users.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'submitty_users.json'], '/'),
    ensure  => file,
    owner => 'root',
    group => 'submitty_daemonphp', # if worker submitty_daemon
    mode => '440',
    content => to_json_pretty(lookup('submitty_users')),
    require => File["config_install_dir"],
  }

  file { 'submitty.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'submitty.json'], '/'),
    ensure  => file,
    owner => 'root',
    mode => '444',
    content => to_json_pretty(lookup('submitty_submitty')),
    require => File["config_install_dir"],
  }

  file { 'database.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'database.json'], '/'),
    ensure  => file,
    owner => 'root',
    group => 'submitty_daemonphp',
    mode => '440',
    content => to_json_pretty(lookup('submitty_database')),
    require => File["config_install_dir"],
  }

  file { 'autograding_workers.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'autograding_workers.json'], '/'),
    ensure  => file,
    owner => 'submitty_php',
    group => 'submitty_daemon',
    mode => '660',
    content => to_json_pretty(lookup('submitty_autograding_workers')),
    require => File["config_install_dir"],
  }

  file { 'autograding_containers.json':
    path => join([lookup('submitty.directories.install.path'), 'config', 'autograding_containers.json'], '/'),
    ensure  => file,
    owner => 'submitty_php',
    group => 'submitty_daemonphp',
    mode => '660',
    content => to_json_pretty(lookup('submitty_autograding_containers')),
    require => File["config_install_dir"],
  }

  # NOTE All this will need the users and groups created first! (right?)

  package { 'python_submitty_utils':
    ensure => installed,
    name => join([lookup('submitty.directories.repository.path'), 'Submitty', 'python_submitty_utils'], '/'),
    provider => pip,
    # install_options =>[]
  }

  class { 'rsync':
    package_ensure => 'latest'
  }

  rsync::get { 'nlohmann-json':
    path => join([lookup('submitty.directories.install.path'), 'vendor'], '/' ),
    source => join([lookup('submitty.directories.repository.path'), 'vendor', 'nlohmann', 'json', 'include'], '/' ),
    recursive => true,
    times => true,
    require => [ Vcsrepo['nlohmann-json'], ],
  }

  rsync::get { lookup("extra_dirs.src.path"):
    source  => join([lookup('submitty.directories.repository.path'), 'Submitty', 'grading'], '/'),
    require => File[ lookup("extra_dirs.src.path") ],
    recursive => true,
    times => true,
  }
  file { 'replace_fillin':
    path => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'replace_fillin.sh'], '/'),
    ensure => present,
    content => epp("profile/submitty/grading/replace_fillin.sh.epp",
                   {
                     'submitty_install_dir' => lookup('submitty.directories.install.path'),
                     'submitty_data_dir' => lookup('submitty.directories.data.path'),
                     'num_untrusted' => lookup('untrusted.number'),
                     'first_untrusted_uid' => lookup('untrusted.start_uid'),
                     'first_untrusted_gid' => lookup('untrusted.start_uid'),
                     'daemon_uid' => lookup('system_users.submitty_daemon.uid'),
                     'daemon_gid' => lookup('system_groups.submitty_daemon.gid'),
                   }),
    mode => '0700',
    require => [Rsync::Get[lookup("extra_dirs.src.path")],]
  }

  lookup("replace_grad").each | String $filename | {
    exec {"fix_${filename}":
      path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      cwd => join([lookup('submitty.directories.install.path'), 'src', 'grading'], '/'),
      command => "bash replace_fillin.sh ${filename}",
      onlyif => "grep  '__FILLIN__' ${filename}",
      require => [File["replace_fillin"],]
    }
  }

  file {'lib_dir':
    path => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'lib'], '/'),
    ensure => directory,
    require => [Rsync::Get[lookup("extra_dirs.src.path")],]
  }

  exec {"compile_grading":
    path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    cwd => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'lib'], '/'),
    command => "cmake .. && make",
    creates => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'lib', 'Makefile'], '/'),
    onlyif => "test ! -f Makefile",
    require => [File["lib_dir"],
                Exec["fix_execute.cpp"],
                Rsync::Get['nlohmann-json'],
               ]
  }

  file { "submitty_router":
    path => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'python', 'submitty_router.py'], '/'),
    ensure => file,
    group => 'submitty_daemon',
    mode => '674',
    require => [Exec['compile_grading'],],
  }


  unless lookup('worker') {
    rsync::get { 'autograding_examples':
      path => lookup('submitty.directories.install.path'),
      source  => join([lookup('submitty.directories.repository.path'), 'Submitty', 'more_autograding_examples'], '/'),
      recursive => true,
      times => true,
    }
  }

  # HELPER BIN
  lookup("rsync").each | String $directory | {
    rsync::get { "${directory}-files":
      # path => lookup('submitty.directories.install.path'),
      path => lookup("extra_dirs.${directory}.path"),
      source  => join([lookup('submitty.directories.repository.path'), 'Submitty', $directory, '*'], '/'),
      recursive => true,
      times => true,
      require => File[ lookup("extra_dirs.${directory}.path") ],
    }
  }

  lookup("change_permissions").each | String $group, Hash $permissions | {
    $permissions['files'].each | String $filename | {
      file {"perm_${filename}":
        path => join([$permissions['parent']['path'], "${filename}"], '/'),
        # ensure => file,
        * => $permissions['options'],
        require => [Rsync::Get['bin-files'], ],
      }
    }
  }




}
