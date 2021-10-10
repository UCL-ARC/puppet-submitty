# Needed as default is still below than 2.28.0
# Newer versions include `--initial-branch for students submissions
require stdlib

class git_latest {
  $architecture = $::facts[os][architecture]
  $os = downcase($::facts[os][name])

  file { '/tmp/hello':
    ensure => file,
    content => "this run on ${os}\n",
  }


  case $os  {
    'ubuntu': {
      require apt
      apt::ppa { 'ppa:git-core/ppa':
        notify => Exec['apt_update'],
      }
    }

    'redhat', 'centos': {
      $releasever = $::facts[os][release][major]

      file { '/etc/yum.repos.d/wandisco-git.repo':
        ensure  => file,
        path    => '/etc/yum.repos.d/wandisco-git.repo',
        content => epp("/wandisco-git.repo.epp", # or git_latest (as I moved it there?)
                       {
                         baseurl => "http://opensource.wandisco.com/${os}/${releasever}/git/${architecture}/",
                       }
                      ),
      }
    }
  }

  package { 'git':
    ensure => 'latest'
  }

}
