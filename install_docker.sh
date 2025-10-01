DISTRIBUTION=$(cat /proc/version)
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
    sudo apt-get install -y apt-transport-https ca-certificates ansible git wget docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif [[ "${DISTRIBUTION}" =~ "Ubuntu" ]]; then
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates ansible git wget docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin nodejs npm
elif [[ "$DISTRIBUTION" == *"Red Hat"* ]]; then
    echo "Installing docker on Red Hat system"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
    sudo systemctl --now enable docker
    sudo dnf install -y epel-release > /dev/null
    sudo dnf update -y > /dev/null
    sudo dnf install -y git wget ansible ansible-core dpkg
fi
