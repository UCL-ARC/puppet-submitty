## site.pp ##

# This file (/etc/puppetlabs/puppet/manifests/site.pp) is the main entry point
# used when an agent connects to a master and asks for an updated configuration.
#
# Global objects like filebuckets and resource defaults should go in this file,
# as should the default node definition. (The default node can be omitted
# if you use the console and don't define any other nodes in site.pp. See
# http://docs.puppetlabs.com/guides/language_guide.html#nodes for more on
# node definitions.)

## Active Configurations ##

# Disable filebucket by default for all File resources:
#https://docs.puppet.com/pe/2015.3/release_notes.html#filebucket-resource-no-longer-created-by-default
# File { backup => false }

# node 'demo' {
#   include role::demo
# }


include git_latest
include basic_dependencies

file {'/etc/motd':
  ensure => present,
  content => epp('motd/motd.epp',
                 {
                   'submission_url' => 'http://mylocalhost',
                   'database_port' => "8332", # FIXME Template (should it be an integer?)
                 }),
  mode => '0644',
}

# FIXME - is there a way to know it's running on vagrant? Set option.
#         other options: Worker / no submission


lookup('system_groups', Hash, 'hash').each | String $groupname, Hash $attrs | {
  group { $groupname:
    * => $attrs,
  }
}

lookup('system_users', Hash, 'hash').each | String $username, Hash $attrs | {
  $attrs.each | String $field, Any $value | {
    # notify {" For ${username} we've got ${field}":}
    if $field == 'profile' {
      file {"/home/${username}/.profile":
        ensure => present,
        content => $value,
        owner => $username,
        require => User[$username],
      }
    }
    elsif $field == 'worker' {
      if $value { # worker == True
        notify {" For ${username} we've got to run something":}
      } else {
        $ensure_user = "absent"
        # FIXME use this variable to remove the user.
        #       I don't know how to set this first...
      }
    }
  }
  user {$username:
    * => delete($attrs, ['profile', 'worker'])
    #FIXME how to do things like createhome/profile/...
  }
}

$data = Integer[0, lookup('untrusted', Integer) - 1]
$data.each | Integer $value | {
  $userid = sprintf("%<y>02d", { 'y' => $value })
  group {"untrusted${userid}":
    gid => 900 + $value
  }
  user {"untrusted${userid}":
    ensure => present,
    uid => 900 + $value,
    gid => 900 + $value,
    home => '/tmp', # Home dir is not created
    comment => "Unstrusted user ${value}",
    require => Group["untrusted${userid}"],
  }
}

# [0, lookup('untrusted', Integer)].step(1).each | Integer $value | {
#   notice sprintf("%<x>s : %<y>d", { 'x' => 'value is', 'y' => $value })
# }


# $value.each | Integer $index, Integer $val | {
#   notice  sprintf("%<val>03d", { 'val' => ${val} })
#   # notify {"untrusted ${newval}": }
#   }

# [0, lookup('untrusted', Integer)].each | Integer, $index, Integer $value | {
#   notify {"untrusted${value} ":}
# }
