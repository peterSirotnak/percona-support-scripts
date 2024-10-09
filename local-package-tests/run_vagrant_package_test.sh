#sudo apt-get update
#sudo apt-get install -y apt-transport-https ca-certificates ansible virtualbox vagrant virtualbox-dkms

export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"

VBGUEST_PLUGIN_PRESENT=$(vagrant plugin list | grep "vbguest")
SCP_PLUGIN_PRESENT=$(vagrant plugin list | grep "vagrant-scp")

if [ -z "$VBGUEST_PLUGIN_PRESENT" ]; then
    vagrant plugin install vagrant-vbguest
fi

if [ -z "$SCP_PLUGIN_PRESENT" ]; then
    vagrant plugin install vagrant-scp
fi

git clone https://github.com/Percona-QA/package-testing.git

cat > Vagrantfile <<EOF
Vagrant.require_version ">= 1.7.0"
Vagrant.configure(2) do |config|
  config.vm.box="generic/ubuntu2204"
  config.vm.synced_folder '.', '/vagrant', disabled: true
  config.ssh.insert_key = false
end
EOF

vagrant up --provider virtualbox
