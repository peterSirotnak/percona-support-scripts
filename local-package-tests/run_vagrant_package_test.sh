#sudo apt-get update
#sudo apt-get install -y apt-transport-https ca-certificates ansible virtualbox vagrant virtualbox-dkms

sudo -E bash -c 'export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"'
sudo -E bash -c 'export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"'
sudo -E bash -c 'export PATH="$PATH:/mnt/c/Windows/System32/"'

#PLUGIN_PRESENT=$(vagrant plugin list | grep "virtualbox")
#
#if [ -z "$PLUGIN_PRESENT" ]; then
#vagrant plugin install vagrant-vbguest
#fi

cat > Vagrantfile <<EOF
Vagrant.require_version ">= 1.7.0"

Vagrant.configure(2) do |config|
  config.vm.box="generic/ubuntu2204"
  config.vm.synced_folder '.', '/vagrant', disabled: true

end
EOF
#config.vm.synced_folder "/c/GIT/", "/pmm/package-testing/"
VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1 vagrant up

#--provider virtualbox
