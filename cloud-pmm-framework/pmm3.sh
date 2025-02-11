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

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin apt-transport-https ca-certificates ansible git wget nodejs npm

sudo docker rm -f watchtower
sudo docker rm -f pmm-server

sudo docker network create pmm-network
sudo docker volume create pmm-volume

sudo docker run --detach --restart always \
	--network="pmm-network" \
	-e WATCHTOWER_DEBUG=1 \
	-e WATCHTOWER_HTTP_API_TOKEN=testUpgradeToken \
	-e WATCHTOWER_HTTP_API_UPDATE=1 \
	--volume /var/run/docker.sock:/var/run/docker.sock \
	--name watchtower \
	perconalab/watchtower:3.0.0-rc

sleep 10

sudo docker run --detach --restart always \
    --network="pmm-network" \
    -e PMM_DEBUG=1 \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_DEV_UPDATE_DOCKER_IMAGE=perconalab/pmm-server:3-dev-latest \
    --publish 80:8080 --publish 443:8443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:3.0.0-rc

git clone https://github.com/Percona-Lab/qa-integration.git
cd qa-integration
git checkout PMM-7-sharded-setup
cd pmm_qa

export PMM_CLIENT_VERSION=3.0.0

echo "Setting docker based PMM clients"
sudo apt install -y python3.12 python3.12-venv
mkdir -m 777 -p /tmp/backup_data
python3 -m venv virtenv
. virtenv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install setuptools

python3 pmm-framework.py --v \
        --verbose \
        --client-version=3-dev-latest --pmm-server-password=admin --database ps --database pgsql --database psmdb

git clone https://github.com/Percona-Lab/qa-integration.git
cd qa-integration
git checkout v3
./pmm_qa/pmm3-client-setup.sh --pmm_server_ip 127.0.0.1 --client_version 3-dev-latest --admin_password admin --use_metrics_mode no
cd ../

cd ../
git clone https://github.com/percona/pmm-ui-tests.git
cd pmm-ui-tests
git checkout checkout v3-typescript
npm i
apt-get install -y libatspi2.0-0t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libglib2.0-0t64 libasound2t64 libnss3 libnspr4 libxdamage1 libpango-1.0-0 libcairo2
npx playwright install chromium
npx codeceptjs run --grep "This is a test"
