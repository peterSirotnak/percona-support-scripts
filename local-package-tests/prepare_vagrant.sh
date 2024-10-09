
if [[ "$VM_BOX" =~ "ubuntu" ]]; then
    sudo apt update -y
    sudo apt install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y ansible git wget
    echo "Installing dependencies for Ubuntu!"
fi

git clone https://github.com/Percona-QA/package-testing.git

echo "These are my \"quotes\"! I am provisioning my guest."
