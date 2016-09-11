#!/bin/bash

set -eux

sudo yum -y update

# vagrant insecure private key 設定
date | sudo tee /etc/vagrant_box_build_time

mkdir ~/.ssh
chmod 700 ~/.ssh/
curl -fsSLo ~/.ssh/authorized_keys https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
chmod 600 ~/.ssh/authorized_keys
chown -R vagrant ~/.ssh

# sshd 設定
sudo sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config

# VirtualBox Guest Additions のインストール準備と実施
# リポジトリ導入、無効化
sudo yum -y install epel-release
sudo sed -i -e 's/^enabled=1/enabled=0/' /etc/yum.repos.d/epel.repo
# 必要パッケージのインストール
sudo yum -y install bzip2 gcc make perl
sudo yum -y --enablerepo=epel install dkms
# VirtualBox Guest Additions のインストール
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
  rpm -q --whatprovides kernel | grep -Fv "$(uname -r)" | xargs sudo yum -y autoremove
fi

sudo yum --enablerepo=epel clean all
sudo yum history new
sudo truncate -c -s 0 /var/log/yum.log

# minimize
sudo dd if=/dev/zero of=/EMPTY bs=1M || :
sudo rm /EMPTY

# In CentOS 7, blkid returns duplicate devices
swap_device_uuid=`sudo /sbin/blkid -t TYPE=swap -o value -s UUID | uniq`
swap_device_label=`sudo /sbin/blkid -t TYPE=swap -o value -s LABEL | uniq`
if [ -n "$swap_device_uuid" ]; then
  swap_device=`readlink -f /dev/disk/by-uuid/"$swap_device_uuid"`
elif [ -n "$swap_device_label" ]; then
  swap_device=`readlink -f /dev/disk/by-label/"$swap_device_label"`
fi
sudo /sbin/swapoff "$swap_device"
sudo dd if=/dev/zero of="$swap_device" bs=1M || :
sudo /sbin/mkswap ${swap_device_label:+-L "$swap_device_label"} ${swap_device_uuid:+-U "$swap_device_uuid"} "$swap_device"
