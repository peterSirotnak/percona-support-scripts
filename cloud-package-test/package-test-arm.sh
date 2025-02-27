sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings

DISTRIBUTION=$(lsb_release -a | grep Description)
echo "$DISTRIBUTION"

if [[ "${DISTRIBUTION}" =~ "Debian" ]]; then
	sudo apt-get install -y dirmngr gnupg2
	echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" | sudo tee -a /etc/apt/sources.list > /dev/null
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
	sudo apt update -y
	sudo apt-get install -y ansible git wget
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
		$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update

elif [[ "${DISTRIBUTION}" =~ "Ubuntu" ]]; then
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
fi

sudo apt-get install -y apt-transport-https ca-certificates ansible git wget

git clone https://github.com/Percona-QA/package-testing.git
cd package-testing
git checkout PMM-13543

export PMM_VERSION=3.0.0

ansible-playbook -vvv --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 playbooks/pmm3-client_integration_custom_path.yml