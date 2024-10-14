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