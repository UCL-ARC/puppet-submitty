class my_apache {
  class { 'apache':}
  $os = downcase($::facts[os][name])

  apache::mod { ['include',
                 'actions',
                 'cgi',
                 # 'suexec',
                 'headers',
                 'ssl',
                 'proxy', # https://ocroquette.wordpress.com/2018/04/30/apache-undefined-symbol-ap_proxy_location_reverse_map/
                 'proxy_fcgi',
                 'rewrite',
                 'proxy_http',
                 'proxy_wstunnel'
  ]:}

  # Ubuntu
  case $os  {
    'ubuntu': {
      package {['libapache2-mod-authnz-external',
                'libapache2-mod-authz-unixgroup',
                'libapache2-mod-wsgi-py3',
                'nginx-full',
               ]:
        ensure => 'latest'
      }
      apache::mod { ['authnz_external',
                     'authz_unixgroup',
                    ]: }
                  # rhel
     notice "Apache installed?"
    }
    'redhat', 'centos': {
      require epel
      apache::mod { ['mod_authnz_external',
                     #'nginx-full',
                    ]: }
    }
  }

  if lookup('vagrant') {
    notice "I'm inside a vagrant box"
    # file not as by default, not sure what's on l153-174.
    $hostname = "localhost"
    $serveradmin = "ADMIN@DOMAIN.HERE"

    $submission_port = lookup("submitty.submission.port", Integer)
    apache::listen { "$submission_port": }

    $submitty_dirs = ['site', 'site/public']
    file {$submitty_dirs.map | $item | {join([lookup('submitty.directories.install.path'), $item], '/')}:
      ensure => 'directory',
      require => File[lookup('submitty.directories.install.path')],
    }
    apache::vhost { 'submitty':
      # ip      => '*',
      port    => $submission_port,
      add_default_charset => 'utf-8',
      serveradmin => $serveradmin,
      docroot => '/usr/local/submitty/site/public',
      scriptaliases => [
        {
          alias => '/cgi-bin',
          path =>  '/usr/local/submitty/site/cgi-bin'
        },
        {
          alias => '/git/',
          path => '/usr/local/submitty/site/cgi-bin/git-http-backend/'
        }
      ],
      directories => [
        {
          path => '/',
          allow_override => 'None',
        },
        {
          path => '/usr/local/submitty/site/public',
          # require all granted missing, but it appears!
          rewrites => [
            {
              rewrite_cond => "%{REQUEST_FILENAME} -f",
              rewrite_rule => "^ - [L]",
            },
            {
              rewrite_cond => "/usr/local/submitty/site/public/index.html -f",
              rewrite_rule => "^ index.html [L]",
            },
            {
              rewrite_rule => '^(.+)/index\\.php$ /index.php?url=$1&%{QUERY_STRING} [NC,END]',
            },
            {
              rewrite_rule => '^(.+)$ /index.php?url=$1&%{QUERY_STRING} [NC,END]',
            },
          ],
          setenv => 'Authorization "(.*)" HTTP_AUTHORIZATION=$1',
        },
        {
          path => '/usr/local/submitty/site/cgi-bin',
          options => '+ExecCGI -MultiViews +SymLinksIfOwnerMatch',
          addhandlers => [
            {
              'handler' => 'cgi-script',
              'extensions' => 'cgi'
            }
          ],
          require => "host ${hostname}",
        },
        {
          path => '/usr/lib/git-core',
          options => '+ExecCGI +SymLinksIfOwnerMatch',
          require => 'all granted',
        },
      ],
      custom_fragment => '
  <FilesMatch "\.php$">
      <If "-f %{REQUEST_FILENAME}">\n
          SetHandler "proxy:unix:/var/run/php/php-fpm-submitty.sock|fcgi://localhost/"
      </If>
  </FilesMatch>

  <Proxy "fcgi://localhost/" enablereuse=on max=20>
  </Proxy>

  <Files .*>
      Require all denied
  </Files>

  <Files *~>
      Require all denied
  </Files>

  <Files #*>
      Require all denied
  </Files>

  <Files "git-http-backend">
      AuthType Basic
      AuthName "Git Access"
      AuthBasicProvider wsgi
      WSGIAuthUserScript /usr/local/submitty/sbin/authentication.py
      Require valid-user
  </Files>
       ',
     # FIXME it doesn't appear, should it be under '/'?
      directoryindex => 'index.html index.php index.cgi',
      suexec_user_group => 'submitty_cgi submitty_cgi',
      log_level => 'warn',
      # FIXME the logs appear for both, but not sure how to change path.
      #error_log_destination => '${APACHE_LOG_DIR}/submitty.log',
      # custom log set alone, this is what we want
      # CustomLog ${APACHE_LOG_DIR}/submitty.log combined
      require => File[join([lookup('submitty.directories.install.path'), "site", "public"], '/')],
      # directory => {'allow_override' => "None",}
    }
  } else {
    $apache_var = lookup("apache", Hash)
    $hostname = $apache_var['host']
    $serveradmin = $apache_var['admin_email']

  }

  $suexec_site = join([lookup('submitty.directories.install.path'), 'site/'], '/')
  File{ 'submitty-suexec':
    path => '/etc/apache2/suexec/www-data',
    # This doesn't work under contetn
    # %{join([lookup('submitty.directories.install.path'), 'site/'], '/')}
    content => "${suexec_site}
cgi-bin
",
    mode => '0640',
    require => Class['apache']
  }

  # nginx
  include nginx

  # NOTE - was it supposed to be different?
  if lookup(vagrant) {
    $nginx_port = lookup("submitty.websocket_port", Integer)
  } else {
    $nginx_port = lookup("submitty.websocket_port", Integer)
  }

  # TODO it also creates index, and access and error logs.
  nginx::resource::server { 'submitty':
    listen_port => $nginx_port,
    # NOTE - missing ip6
    listen_options => 'default_server',
    server_name => ['_'],
    use_default_location => false,
    locations => {
      '/' => {
        location_cfg_append => {return => 404},
      },
      '/ws' => {
        proxy => 'http://127.0.0.1:41983',
        proxy_http_version => "1.1",
        proxy_set_header => [
          'Upgrade $http_upgrade',
          'Connection "Upgrade"',
          'Host $host',
          ]
      },
    }
}

}
