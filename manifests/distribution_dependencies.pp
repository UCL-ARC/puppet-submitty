class distribution_dependencies {
  $os = downcase($::facts[os][name])
  case $os  {
    'ubuntu': {
      package { [
        'apt-transport-https',
        'python-dev',
        'python3-dev',
        'libpython3.6',
        'libpam-passwdqc', # is this provided by pam?
        'openssh-client',
        'sshpass', ## is it needed?
        'apache2-suexec-custom',
        'php-curl',
        'php-zip',
        #'php-ds', # pecl
        'scrot',
        'autotools-dev',
        'finger',
        'p7zip-full',
        'libpq-dev',
        'libboost-all-dev',
        'g++',
        'g++-multilib',
        'libseccomp-dev',
        'libseccomp2',
        'seccomp',
        'junit',
        'ninja-build',
        'python-clang-6.0',
        'imagemagick',
        'libzbar0',
        'libtclap-dev',
      ]:
      ensure => 'latest',
      }
    }
    'redhat', 'centos': {
      require epel
      package {[
        'python36-devel',
        'platform-python-devel',
        'openssh-clients',
        #pam_passwdqc # https://centos.pkgs.org/8/lux/pam_passwdqc-2.0.2-2.el8.lux.x86_64.rpm.html
        # sshpass is not available,
        # 'apache2-suexec-custom', ## Not found!
        # 'mod_authz_unixgroup',
        'python3-mod_swgi',
        # 'php-curl', # not found!
        # 'php-zip', # NF
        # 'php-ds', # pecl?
        # 'scrot' # https://centos.pkgs.org/7/psychotic-ninja-x86_64/scrot-0.8-12.el7.psychotic.x86_64.rpm.html
        # 'autotools-dev' # NF
        # finger # Not in Centos 8 ?? but it's on 7
        # 'p7zip-full', #NF
        'p7zip',
        'libpq-devel',
        'boost-devel',
        'gcc-c++',
        # 'g++-multilib', # NF
        'libseccomp-devel',
        'libseccomp',
        # 'seccomp', # NF
        # 'junit', # https://centos.pkgs.org/8/centos-powertools-aarch64/junit-4.12-9.module_el8.0.0+30+832da3a1.noarch.rpm.html
        # 'ninja-build', # NF https://centos.pkgs.org/8/centos-powertools-x86_64/ninja-build-1.8.2-1.el8.x86_64.rpm.html | EPEL for 7
        'python3-clang',
        'ImageMagick',
        'ImageMagick-devel', # to install imagick fro pecl
        # 'libzbar0',
        # 'libtclap' # It doesn't exist... create package?
      ]:
      ensure => 'latest',
      }

    }
    }

}
