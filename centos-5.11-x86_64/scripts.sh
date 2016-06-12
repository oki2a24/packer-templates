#!/bin/bash

set -e
set -x

# 不要な inittab 無効化
sudo sed -i -e 's,^.*:/sbin/mingetty\s\+tty[2-6],#\0,' /etc/inittab

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
curl -L -O https://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-5
sudo rpm --import RPM-GPG-KEY-EPEL-5
rm RPM-GPG-KEY-EPEL-5
curl -L -O https://download.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
sudo yum -y install epel-release-5-4.noarch.rpm
rm epel-release-5-4.noarch.rpm
sudo sed -i -e 's/^enabled=1/enabled=0/' /etc/yum.repos.d/epel.repo

sudo yum -y install bzip2
sudo yum -y --enablerepo=epel install dkms
sudo yum -y install make
sudo yum -y install perl

sudo mount -o loop,ro ~/VBoxGuestAdditions.iso /mnt/
sudo /mnt/VBoxLinuxAdditions.run || :
sudo umount /mnt/
rm -f ~/VBoxGuestAdditions.iso

# locale
sudo find /usr/lib/locale -mindepth 1 -maxdepth 1 -type d -not -name ja_JP.utf8 -exec rm -r {} +
sudo /usr/sbin/build-locale-archive
sudo rm -r /usr/lib/locale/ja_JP.utf8

# cleanup
sudo yum --enablerepo=epel clean all
sudo tee /var/log/yum.log < /dev/null

# minimize
sudo dd if=/dev/zero of=/EMPTY bs=1M || :
sudo rm /EMPTY
