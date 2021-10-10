#!/bin/bash

if [[ -f /etc/redhat-release ]]; then
    # centos doesn't include lsb-release (don't know about redhat)
    dnf -y install redhat-lsb-core
fi

distrib=$(lsb_release -a | grep "Distributor ID" | awk '{print $3}')

if [[ $distrib == *"Ubuntu"* ]]; then
    source /etc/lsb-release

    wget https://apt.puppetlabs.com/puppet-release-${DISTRIB_CODENAME}.deb
    dpkg -i puppet-release-${DISTRIB_CODENAME}.deb
    apt-get update
    apt-get -y install puppet-agent gcc

elif [[ $distrib == *"RedHat"* ]] || [[ $distrib == *"CentOS"* ]]; then

    release=$(lsb_release -a | grep "Release" | awk '{print $2}' | cut -f1 -d.)
    dnf -y install https://yum.puppetlabs.com/puppet-release-el-${release}.noarch.rpm
    dnf -y update
    dnf -y install puppet-agent gcc # for gpgme compilation
fi

# Adds puppet path to sudo.
echo 'Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin"' >/etc/sudoers.d/puppet

# Installs extra plugins for puppet
plugins=(gpgme hiera-eyaml-gpg r10k generate-puppetfile)
for plugin in "${plugins[@]}"; do
    /opt/puppetlabs/puppet/bin/gem install "${plugin}" --no-document
done

# Don't want to expand PATH now!
# shellcheck disable=2016
echo 'PATH=/opt/puppetlabs/puppet/bin/:${PATH}' >> /root/.bashrc

cd /etc/puppetlabs/code/environments/production
/opt/puppetlabs/puppet/bin/r10k puppetfile install --verbose
/opt/puppetlabs/bin/puppet apply --environment=production /etc/puppetlabs/code/environments/production/manifests
