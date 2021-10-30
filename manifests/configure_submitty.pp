class submitty_config {

  $submitty_dirs = lookup('submitty.directories', Hash)
  $submitty_dirs.each | String $item, Hash $options | {
    file {$options['path']:
      ensure => directory,
      *      => $options,
    }
  }

  ## Submitty data
  $submitty_extra_dirs = lookup('extra_dirs', Hash)
  $submitty_extra_dirs.each | String $item, Hash $options | {
    # notice("Creating ${options['path']}")
    file {$options['path']:
      ensure  => directory,
      *       => delete($options, ['require']),
      require => [File[lookup('submitty.directories.install.path')],
                  File[lookup('submitty.directories.repository.path')],
                  File[lookup('submitty.directories.data.path')],
                  $options['require'],
                  ]
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
    ensure  => directory,
    require => File[lookup('submitty.directories.data.path')]
  }

  file {"${data_dir}/instructors/valid":
    ensure  => present,
    # FIXME: it still needs the users that are not system users
    content => join(sort(lookup('system_users', Hash, 'hash').map |$key, $value| {$key}), "\n")
  }

  file { 'submitty_conf.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), '.setup', 'submitty_conf.json'], '/'),
    owner   => 'root',
    mode    => '0500',
    content => to_json_pretty(lookup('submitty_configuration')),
    require => File[lookup('extra_dirs.setup.path')],
  }
  ### Create INSTALL_SUBMITTY.sh 700 and
  # FIXME is it needed?

  file { 'email.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'email.json'], '/'),
    owner   => 'root',
    group   => 'submitty_daemonphp',
    mode    => '0400',
    content => to_json_pretty(lookup('submitty_email')),
    require => File[lookup('extra_dirs.config.path')],
  }

  file { 'submitty_admin.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'submitty_admin.json'], '/'),
    owner   => 'root',
    group   => 'submitty_daemon',
    mode    => '0400',
    content => to_json_pretty(lookup('submitty_admin')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  file { 'secrets_submitty_php.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'secrets_submitty_php.json'], '/'),
    owner   => 'root',
    group   => 'submitty_php',
    mode    => '0440',
    content => to_json_pretty(lookup('submitty_secrets_php')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  file { 'submitty_users.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'submitty_users.json'], '/'),
    owner   => 'root',
    group   => 'submitty_daemonphp', # if worker submitty_daemon
    mode    => '0440',
    content => to_json_pretty(lookup('submitty_users')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  file { 'submitty.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'submitty.json'], '/'),
    owner   => 'root',
    mode    => '0444',
    content => to_json_pretty(lookup('submitty_submitty')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  file { 'database.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'database.json'], '/'),
    owner   => 'root',
    group   => 'submitty_daemonphp',
    mode    => '0440',
    content => to_json_pretty(lookup('submitty_database')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  file { 'autograding_workers.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'autograding_workers.json'], '/'),
    owner   => 'submitty_php',
    group   => 'submitty_daemon',
    mode    => '0660',
    content => to_json_pretty(lookup('submitty_autograding_workers')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  file { 'autograding_containers.json':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'config', 'autograding_containers.json'], '/'),
    owner   => 'submitty_php',
    group   => 'submitty_daemonphp',
    mode    => '0660',
    content => to_json_pretty(lookup('submitty_autograding_containers')),
    require => File[lookup('extra_dirs.setup.path')],
  }

  # NOTE All this will need the users and groups created first! (right?)

  package { 'python_submitty_utils':
    ensure   => installed,
    name     => join([lookup('submitty.directories.repository.path'), 'Submitty', 'python_submitty_utils'], '/'),
    provider => pip,
    # install_options =>[]
  }

  class { 'rsync':
    package_ensure => 'latest'
  }

  rsync::get { 'nlohmann-json':
    path      => join([lookup('submitty.directories.install.path'), 'vendor'], '/' ),
    source    => join([lookup('submitty.directories.repository.path'), 'vendor', 'nlohmann', 'json', 'include'], '/' ),
    recursive => true,
    times     => true,
    require   => [ Vcsrepo['nlohmann-json'], ],
  }

  rsync::get { lookup('extra_dirs.src.path'):
    source    => join([lookup('submitty.directories.repository.path'), 'Submitty', 'grading'], '/'),
    require   => File[ lookup('extra_dirs.src.path') ],
    recursive => true,
    times     => true,
  }
  file { 'replace_fillin':
    ensure  => present,
    path    => join([lookup('extra_dirs.src-grading.path'), 'replace_fillin.sh'], '/'),
    content => epp('profile/submitty/grading/replace_fillin.sh.epp',
                   {
                     'submitty_install_dir' => lookup('submitty.directories.install.path'),
                     'submitty_data_dir'    => lookup('submitty.directories.data.path'),
                     'num_untrusted'        => lookup('untrusted.number'),
                     'first_untrusted_uid'  => lookup('untrusted.start_uid'),
                     'first_untrusted_gid'  => lookup('untrusted.start_uid'),
                     'daemon_uid'           => lookup('system_users.submitty_daemon.uid'),
                     'daemon_gid'           => lookup('system_groups.submitty_daemon.gid'),
                   }),
    mode    => '0700',
    require => [Rsync::Get[lookup('extra_dirs.src.path')],]
  }

  lookup('replace').each | String $groupname, Hash $group | {
    $group['files'].each | String $filename | {
      $filepath = join([$group['parent']['path'], $filename], '/')
      exec {"${groupname}_fix_${filename}":
        path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
        cwd     => lookup('extra_dirs.src-grading.path'),
        command => "bash replace_fillin.sh ${filepath}",
        onlyif  => "grep  '__FILLIN__' ${filepath}",
        require => [File['replace_fillin'],
                    File['untrusted_exec'],
                   ]
      }
    }
  }
  file {'lib_dir':
    ensure  => directory,
    path    => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'lib'], '/'),
    require => [Rsync::Get[lookup('extra_dirs.src.path')],]
  }

  exec {'compile_grading':
    path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    cwd     => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'lib'], '/'),
    command => 'cmake .. && make',
    creates => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'lib', 'Makefile'], '/'),
    onlyif  => 'test ! -f Makefile',
    require => [File['lib_dir'],
                Exec['grad_fix_execute.cpp'],
                Rsync::Get['nlohmann-json'],
               ]
  }

  file { 'submitty_router':
    ensure  => file,
    path    => join([lookup('submitty.directories.install.path'), 'src', 'grading', 'python', 'submitty_router.py'], '/'),
    group   => 'submitty_daemon',
    mode    => '0674',
    require => [Exec['compile_grading'],],
  }


  unless lookup('worker') {
    rsync::get { 'autograding_examples':
      path      => lookup('submitty.directories.install.path'),
      source    => join([lookup('submitty.directories.repository.path'), 'Submitty', 'more_autograding_examples'], '/'),
      recursive => true,
      times     => true,
    }
  }

  # HELPER BIN
  lookup('rsync').each | String $directory, Hash $properties | {
    if 'repo' in $properties {
      $rsync_source=$directory
    } else {
      $rsync_source=join(['Submitty', $directory], '/')
    }
    if 'subdir' in $properties {
      $rsync_path = join([$rsync_source, $properties['subdir']], '/')
    } else {
      $rsync_path = $rsync_source
    }
    rsync::get { "${directory}-files":
      # path => lookup('submitty.directories.install.path'),
      path      => lookup("extra_dirs.${directory}.path"),
      source    => join([lookup('submitty.directories.repository.path'), $rsync_path, '*'], '/'),
      recursive => true,
      times     => true,
      require   => File[ lookup("extra_dirs.${directory}.path") ],
      *         => $properties['options'],
    }
  }

  lookup('change_permissions').each | String $group, Hash $permissions | {
    $name=split($group, '_')[0]
    $permissions['files'].each | String $filename | {
      # notice("Changing perms of ${name} ${filename}")
      file {"perm_${filename}":
        path    => join([$permissions['parent']['path'], $filename], '/'),
        # ensure => file,
        require => [Rsync::Get["${name}-files"],
                    $permissions['options']['require']],
        *       => delete($permissions['options'], 'require')
      }
    }
  }



  file { 'untrusted_exec':
    path    => join([lookup('extra_dirs.setup.path'), 'untrusted_execute.c'], '/'),
    source  => join([lookup('submitty.directories.repository.path'), 'Submitty', '.setup', 'untrusted_execute.c'], '/'),
    owner   => 'root',
    group   => 'root',
    mode    => '0500',
    require => [File[lookup('extra_dirs.setup.path')],
                Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Submitty'], '/')],
               ],
  }

  file { 'compile_bin':
    ensure  => present,
    path    => join([lookup('extra_dirs.bin.path'), 'compile_bin.sh'], '/'),
    content => epp('profile/submitty/grading/compile_bin.sh.epp',
                   {
                     'submitty_install_dir' => lookup('submitty.directories.install.path'),
                     'submitty_setup_dir'   => lookup('extra_dirs.setup.path'),
                   }),
    mode    => '0700',
    require => [File[lookup('extra_dirs.bin.path')],]
  }
  exec {'compile_bin':
    path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    cwd     => lookup('extra_dirs.bin.path'),
    command => 'bash compile_bin.sh',
    onlyif  => 'test ! -f system_call_check.out',
    require => [File['compile_bin'],
                File['untrusted_exec'],
                Rsync::Get['bin-files'],
                File[lookup('extra_dirs.src.path')],
                Exec['setup_fix_untrusted_execute.c'],
               ]
    }


    lookup('copy_setup_bin.files').each | String $filename | {
      file { "setup-bin-${filename}":
        path    => join([lookup('extra_dirs.setup-bin.path'), $filename], '/'),
        source  => join([lookup('submitty.directories.repository.path'), 'Submitty', '.setup', 'bin', $filename], '/'),
        *       => lookup('copy_setup_bin.options'),
        require => [File[lookup('extra_dirs.setup-bin.path')],
                    Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Submitty'], '/')],
                    ]

      }
    }


    #############install_site
    ### Create cronjob to run script to update permissions of /usr/local/submitty/site
    file { 'cron_site_permissions':
      ensure  => present,
      path    => '/root/.cron_update_site_permissions.sh',
      content => epp('profile/submitty/grading/update_site_permissions.sh.epp',
                     {
                       'submitty_install_dir' => lookup('submitty.directories.install.path'),
                     }),
    mode      => '0700',
    }
    cron { 'site_permissions':
      command => '/root/.cron_update_site_permissions.sh',
      user    => 'root',
      month   => '1',
      #hour    => '*/10',  # FIXME change it to minutes
      #minute  => '*/10',
      require => File['cron_site_permissions'],
    }

    # install composer dependencies
    $extra_dirs_site = lookup('extra_dirs.site.path')
    exec {'composer-dependencies':
      path        => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      cwd         => lookup('extra_dirs.site.path'),
      user        => 'submitty_php',
      environment => [ 'HOME=/home/submitty_php',],
      command     => "composer install -d ${extra_dirs_site} --no-dev --prefer-dist --optimize-autoloader --no-progress --no-ansi > /tmp/puppet_output_composer_dependencies 2>&1",
      onlyif      => "composer install -d ${extra_dirs_site} --dry-run 2>&1 | grep -E -- '- (Install|Updat)ing '",
      require     => [Rsync::Get['site-files'],
                  File[lookup('extra_dirs.site-vendor.path')],
                 ],
      loglevel    => debug,
      logoutput   => 'on_failure',
    }
    exec {'npm-dependencies':
      path        => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      cwd         => lookup('extra_dirs.site.path'),
      user        => 'submitty_php',
      environment => [ 'HOME=/home/submitty_php',],
      command     => 'npm install --loglevel=error --no-save > /tmp/puppet_output_npm_dependencies 2>&1',
      onlyif      => "npm install --dry-run 2>&1 | grep -E -- 'added '",
      require     => [Rsync::Get['site-files'],
                  File[lookup('extra_dirs.site-vendor.path')],
                  Class['nodejs'],
                 ],
      loglevel    => debug,
      logoutput   => 'on_failure',
    }
    file { 'copy-npm':
      ensure  => present,
      path    => join([lookup('extra_dirs.bin.path'), 'copy_npm_public.sh'], '/'),
      content => epp('profile/submitty/grading/copy_npm_public.sh.epp',
                     {
                       'submitty_install_dir' => lookup('submitty.directories.install.path'),
                     }
                    ),
      mode    => '0700',
      require => [Exec['npm-dependencies'],]
    }

    exec {'copy-npm':
      path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      cwd     => lookup('extra_dirs.bin.path'),
      command => 'bash copy_npm_public.sh',
      onlyif  => 'test ! -f copied_npm',
      require => [File['copy-npm'],
                 ]
    }

    # How to reload php? that should be the end
    # systemctl reload php${PHP_VERSION}-fpm


    lookup('copy_analysis_compile.groups').each | String $group, Hash $properties | {
      $origin_name=split($group, '_')[0]
      $destin_name=split($group, '_')[1]
      $properties['files'].each | String $filename | {
        $file_name = $filename ? {
          /CMakeLists.*\.txt/         => 'CMakeLists.txt',
          default                     => $filename,
        }
        file { "copy-analysis-${destin_name}_${filename}":
          path    => join([$properties['dest_path'], $file_name], '/'),
          source  => join([lookup('copy_analysis_compile.parent_origin_path'), $origin_name, $filename], '/'),
          require => [Vcsrepo[join([lookup('submitty.directories.repository.path'), 'AnalysisTools'], '/')],
                      $properties['require'],
                     ],
          *       => lookup('copy_analysis_compile.options')
        }
      }
    }

    $traversal_types = {'commonASTCount' => '', 'unionCount' => 'Union'}
    $traversal_types.each | String $out, String $traversal | {
      $path_out = join([lookup('extra_dirs.AnalysisTools.path'), "${out}.out"], '/')
      exec { "ASTTraversal-${traversal}":
        path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
        cwd     => join([lookup('submitty.directories.repository.path'), 'AnalysisTools', 'commonAST'], '/'),
        command => "g++ parser${traversal}.cpp traversal${traversal}.cpp -o ${path_out}",
        onlyif  => "test ! -f ${path_out}",
        require => [Vcsrepo[join([lookup('submitty.directories.repository.path'), 'AnalysisTools'], '/')],
                    File[lookup('extra_dirs.AnalysisTools.path')],
                   ],
      }

    }

    # FIXME this has to run when there's something serving the site!!!
    # unless lookup('worker') {
    #   # NOTE is this going to work if the server is unavailable?
    #   exec { 'rainbow-init':
    #     path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    #     cwd     => lookup('extra_dirs.setup-bin.path'),
    #     command => 'python3 init_auto_rainbow.py > /tmp/puppet_rainbow_init.out 2>&1',
    #     require => [Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Submitty'], '/')],
    #                 File[lookup('extra_dirs.setup-bin.path')],
    #                ],
    #   }

    # }

    # Lichen bin script conversions
    rsync::get { 'nlohmann-json-lichen':
      path      => lookup('extra_dirs.Lichen-vendor-nlohmann.path'),
      source    => join([lookup('submitty.directories.repository.path'), 'vendor', 'nlohmann',
                         'json', 'include', 'nlohmann', '*'], '/' ),
      recursive => true,
      times     => true,
      require   => [ Vcsrepo['nlohmann-json'],
                     File[lookup('extra_dirs.Lichen-vendor-nlohmann.path')],
                   ],
    }
    exec {'lichen-build-hashes':
      path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      cwd     =>  join([lookup('submitty.directories.repository.path'), 'Lichen'], '/'),
      command => "clang++ -I ${lookup('extra_dirs.Lichen-vendor.path')} -lboost_system -lboost_filesystem -Wall -Wextra -Werror -g -O3 -flto -funroll-loops -std=c++11 compare_hashes/compare_hashes.cpp -o ${lookup('extra_dirs.Lichen-bin.path')}/compare_hashes.out",
      require => [Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Lichen'], '/')],
                  File[lookup('extra_dirs.Lichen-bin.path')],
                  Rsync::Get['nlohmann-json-lichen'],
                 ],
    }
    exec {'lichen-build-token':
      path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
      cwd     =>  join([lookup('submitty.directories.repository.path'), 'Lichen'], '/'),
      command => "clang++ -I ${lookup('extra_dirs.Lichen-vendor.path')} -std=c++11 -Wall -O3 tokenizer/plaintext/plaintext_tokenizer.cpp -o  ${lookup('extra_dirs.Lichen-bin.path')}/plaintext_tokenizer.out",
      require => [Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Lichen'], '/')],
                  File[lookup('extra_dirs.Lichen-bin.path')],
                  Rsync::Get['nlohmann-json-lichen'],
                 ],
    }

    lookup('copy_lichen_tokenizer.files').each | String $filename | {

      $file_name = $filename ? {
        /\w*\/+\w*/ => split($filename, '/')[1],
        default     => $filename,
      }
      notice("The file is ${file_name}")

      file { "lichen-tokenizer-${file_name}":
        path    => join([lookup('extra_dirs.Lichen-bin.path'), $file_name], '/'),
        source  => join([lookup('submitty.directories.repository.path'), 'Lichen', 'tokenizer', $filename], '/'),
        *       => lookup('copy_lichen_tokenizer.options'),
        require => [Vcsrepo[join([lookup('submitty.directories.repository.path'), 'Lichen'], '/')],
                    File[lookup('extra_dirs.Lichen-bin.path')],
                   ],
      }
    }

}
