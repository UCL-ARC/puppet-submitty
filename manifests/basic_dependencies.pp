class basic_dependencies {
  $_os = downcase($::facts[os][name])

package { [
  'ca-certificates',
  'curl',
  'python3', # 3.8.2 in ubuntu vs 3.6 in centos
  'python3-pip',
  'openssh-server',
  'unzip',
  'php-pgsql',
  'php-mbstring',
  'php-xml',
  'clang',
  'autoconf',
  'automake',
  'diffstat',
  'gdb',
  'patchutils',
  'valgrind',
  'zip',
  'gcc',
  'jq',
  'flex',
  'bison',
  'poppler-utils',
  'cmake',
  'emacs',
]:
  ensure => 'latest',
}

include distribution_dependencies
include ntp

class { 'postgresql::globals':
  manage_package_repo => true,
  version             => '12', # NOTE it should be 12.8
}

class { 'postgresql::server':
}


include my_apache


$extensions = {
  imagick => {
    # TODO check if works in centos!
  },
  ds   => {
    # FIXME launching php shows an error about file ds.so.so doesn't exist.
    ini_prefix => '21-', # NOTE this is setting in /etc/php/7.4/mods-available/21-ds.ini.
  },
}
if lookup('vagrant') {
  $php_extensions = {'extensions' => ($extensions + {'xdebug' => {
    settings_prefix => true,
    settings => {
      remote_enable => 1,
      remote_port => 9000,
      remote_host => "10.0.2.2",
      profiler_enable_trigger =>1,
      profiler_output_dir => join([lookup('submitty', Hash)['repository'], "/.vagrant/Ubuntu/profiler"], ''),
      }
  }})}
} else {
  $php_extensions = {'extensions' => $extensions}
}
notice $php_extensions
class { '::php':
  ensure       => latest,
  manage_repos => true,
  fpm          => true,
  phpunit      => false,
  composer     => true,
  * => $php_extensions,
}
# NOTE this may still be needed - or the prefix above works?
# A work around based on https://github.com/php-ds/ext-ds/issues/2
# exec { 'php: fix ds-json':
#   path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
#   cwd     => "/etc/php/7.4/cli/conf.d",
#   command => "mv 20-json.ini 19-json.ini",
#   creates => "/etc/php/7.4/cli/conf.d/19-json.ini",
#   onlyif  => "test -f /etc/php/7.4/cli/conf.d/20-json.ini",
#   require => Class['::php'],
# }
php::fpm::pool { 'submitty':
  user => submitty_php,
  group => submitty_php,
  listen => '/run/php/php-fpm-submitty.sock',
  listen_owner => 'www-data',
  listen_group => 'www-data',
  pm => 'dynamic',
  pm_max_children => 20,
  pm_start_servers => 4,
  pm_min_spare_servers => 2,
  pm_max_spare_servers => 6,
}

class { 'nodejs': } # FIXME (maybe) - should we restrict it to version 12?
include 'docker'


# Python dependencies

class pypackage {
  $pip_require = lookup('pip_require', Hash)
  $pip_require.each | String $pippacakage, String $version | {
    package { $pipppackage:
      ensure   => $version,
      provider => 'pip',
    }

  }

}

# TODO - add java r10k and dependencies
# class { 'java':
#   distribution => 'jre',
# }

# TODO - convert to module
$package_name        = 'tclap'
$package_version     = '1.2.2'
$install_path        = "/tmp/"
$repository_url      = "https://sourceforge.net/projects/tclap/files/"
$archive_name        = "${package_name}-${package_version}.tar.gz"
$package_source      = "${repository_url}/${archive_name}"
$package_directory   = "${install_path}/${package_name}-${package_version}"
$install_command     = "bash configure; make; make install"
$package_sample      = "/usr/local/include/tclap/Arg.h"

archive { $archive_name:
  path         => "/tmp/${archive_name}",
  source       => $package_source,
  extract      => true,
  extract_path => $install_path,
  creates      => "${package_directory}",
  cleanup      => true,
}
file_line { 'tclap_make':
  ensure => present,
  path   => "${install_path}/${package_name}-${package_version}/Makefile.in",
  line   => "SUBDIRS = include docs msc config",
  match  => 'SUBDIRS = include examples docs tests msc config',
  require => Archive["${archive_name}"],
}
exec { "Install ${package_name} ${package_version}":
  path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
  cwd     => $package_directory,
  command => $install_command,
  creates => $package_sample,
  require => File_line['tclap_make'],
}

}
