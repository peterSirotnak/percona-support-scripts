if [[ "$VM_BOX" =~ "ubuntu" ]]; then
    sudo apt update -y
    sudo apt install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y ansible-core git wget
fi

PMM_SERVER_IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
echo "PMM Server ip is: $PMM_SERVER_IP"

git clone https://github.com/Percona-QA/package-testing.git
git checkout PMM-7-default-ip

ansible-playbook --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 package-testing/playbooks/$PLAYBOOK_FILE.yml
