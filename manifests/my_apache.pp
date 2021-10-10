class my_apache {
  class { 'apache':}
  $os = downcase($::facts[os][name])

  apache::mod { ['include',
                 'actions',
                 'cgi',
                 'suexec',
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

  # nginx
  include nginx

  if lookup('vagrant') {
    notice "I'm inside a vagrant box"

  }

}
