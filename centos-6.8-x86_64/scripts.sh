#!/bin/bash

set -e
set -x

# 不要な tty 無効化
sudo sed -i -e 's,^ACTIVE_CONSOLES=.*$,ACTIVE_CONSOLES=/dev/tty1,' /etc/sysconfig/init

# vagrant insecure private key 設定
date | sudo tee /etc/vagrant_box_build_time

mkdir ~/.ssh
chmod 700 ~/.ssh/
curl -fsSLo ~/.ssh/authorized_keys https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
chmod 600 ~/.ssh/authorized_keys
chown -R vagrant ~/.ssh

# sshd 設定
sudo sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config

# VirtualBox Guest Additions のインストール
# リポジトリ導入、無効化
sudo yum -y install https://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo sed -i -e 's/^enabled=1/enabled=0/' /etc/yum.repos.d/epel.repo

sudo yum -y --enablerepo=epel install dkms
# In CentOS 6 or earlier, dkms package provides SysV init script called
# dkms_autoinstaller that is enabled by default
sudo yum -y install kernel-devel perl

sudo mount -o loop,ro ~/VBoxGuestAdditions.iso /mnt/
sudo /mnt/VBoxLinuxAdditions.run || :
sudo umount /mnt/
rm -f ~/VBoxGuestAdditions.iso

# locale
localedef --list-archive | grep -a -v ja_JP.utf8 | xargs sudo localedef --delete-from-archive
sudo cp /usr/lib/locale/locale-archive{,.tmpl}
sudo build-locale-archive

# cleanup
if rpm -q --whatprovides kernel | grep -Fqv "$(uname -r)"; then
  rpm -q --whatprovides kernel | grep -Fv "$(uname -r)" | xargs sudo yum -y remove
fi

sudo yum --enablerepo=epel clean all
sudo yum history new
sudo truncate -c -s 0 /var/log/yum.log

# minimize
sudo dd if=/dev/zero of=/EMPTY bs=1M || :
sudo rm /EMPTY
