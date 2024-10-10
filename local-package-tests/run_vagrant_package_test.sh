#sudo apt-get update
#sudo apt-get install -y apt-transport-https ca-certificates ansible virtualbox vagrant virtualbox-dkms

for flag in "$@"
do
    if [[ $flag =~ "distribution" ]]
    then
        if [[ $2 == 'jammy' ]]; then
            VM_BOX=generic/ubuntu2204
        fi
        shift 2
    elif [[ $flag =~ "playbook" ]]
    then
        PLAYBOOK_FILE=$2
        shift 2
    fi
done

echo "VM Box is: $VM_BOX"
echo "Playbook is: $PLAYBOOK_FILE"

export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"

VBGUEST_PLUGIN_PRESENT=$(vagrant plugin list | grep "vbguest")
SCP_PLUGIN_PRESENT=$(vagrant plugin list | grep "vagrant-scp")
WSL_PLUGIN_PRESENT=$(vagrant plugin list | grep "virtualbox_WSL2")

if [ -z "$VBGUEST_PLUGIN_PRESENT" ]; then
    vagrant plugin install vagrant-vbguest
fi

if [ -z "$SCP_PLUGIN_PRESENT" ]; then
    vagrant plugin install vagrant-scp
fi

if [ -z "$WSL_PLUGIN_PRESENT" ]; then
    vagrant plugin install virtualbox_WSL2
fi

#if wsl
#config.vm.provider "virtualbox" do |vb|
#     vb.gui = true
#   end
if [[ ! $(apt list --installed | grep "docker") =~ "docker" ]]; then
  ./install_docker.sh
fi

vagrant destroy -f default

sudo docker rm -f pmm-server

sudo docker volume create pmm-volume
sudo docker network create pmm-network

sudo docker run --detach --restart always \
            --network="pmm-network" \
            -e PMM_DEBUG=1 \
            --publish 80:8080 --publish 443:8443 \
            --volume pmm-volume \
            --name pmm-server \
            perconalab/pmm-server:3.0.0

cat > Vagrantfile <<EOF
Vagrant.require_version ">= 1.7.0"
Vagrant.configure(2) do |config|
    config.vm.box="$VM_BOX"
    config.vm.synced_folder '.', '/vagrant', disabled: true
    config.ssh.insert_key = false
    config.vm.provision "shell", path: "prepare_vagrant.sh", env: { "VM_BOX" => "$VM_BOX", "PLAYBOOK_FILE" => "$PLAYBOOK_FILE"}
end
EOF

vagrant up --provider virtualbox

vagrant destroy -f default
