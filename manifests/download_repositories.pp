class download_repositories {


  # FIXME for now it will only clone.
  lookup('versions.submitty').each | String $prog, String $version | {
  vcsrepo { join([lookup('submitty.directories.repository.path'), $prog], '/'):
    ensure   => present,
    provider => git,
    source   =>  "https://github.com/Submitty/${prog}",
    revision => $version,
  }
}
vcsrepo { 'nlohmann-json':
  ensure   => present,
  path     => join([lookup('submitty.directories.repository.path'), 'vendor', 'nlohmann', 'json'], '/' ),
  provider => git,
  source   => 'https://github.com/nlohmann/json.git',
  depth    => 1,
}

}
