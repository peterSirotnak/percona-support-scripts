LINUX_DISTRIBUTION=$(cat /proc/version)
if [[ "$LINUX_DISTRIBUTION" == *"Ubuntu"* ]]; then
    echo "Installing docker on Ubuntu system"
    sudo apt-get update > /dev/null
    sudo apt-get install ca-certificates curl > /dev/null
    sudo install -m 0755 -d /etc/apt/keyrings > /dev/null
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc > /dev/null
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update > /dev/null
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null
elif [[ "$LINUX_DISTRIBUTION" == *"Red Hat"* ]]; then
    echo "Installing docker on Red Hat system"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
    sudo systemctl --now enable docker
    sudo dnf install -y epel-release > /dev/null
    sudo dnf update -y > /dev/null
    sudo dnf install -y git wget ansible > /dev/null
fi

docker network create pmm-qa || true
docker volume create pmm-data

DOCKER_VERSION=perconalab/pmm-server:3-dev-latest

docker run --detach --restart always \
    --network="pmm-qa" \
    -e WATCHTOWER_DEBUG=1 \
    -e WATCHTOWER_HTTP_API_TOKEN=testUpgradeToken \
    -e WATCHTOWER_HTTP_API_UPDATE=1 \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --name watchtower \
    perconalab/watchtower:latest

sleep 10

docker run --detach --restart always \
    --network="pmm-qa" \
    -e PMM_DEBUG=1 \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_ENABLE_UPDATES=1 \
    --publish 80:8080 --publish 443:8443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
    $DOCKER_VERSION

wget https://raw.githubusercontent.com/Percona-Lab/qa-integration/refs/heads/v3/pmm_qa/pmm3-client-setup.sh
chmod +x pmm3-client-setup.sh
bash -x ./pmm3-client-setup.sh --pmm_server_ip 127.0.0.1 --client_version 3-dev-latest --admin_password admin --use_metrics_mode no

set -o errexit
set -o xtrace
git clone https://github.com/Percona-Lab/qa-integration.git
git checkout v3
cd qa-integration/pmm-qa/
echo "Setting docker based PMM clients"
mkdir -m 777 -p /tmp/backup_data
python3 -m venv virtenv
. virtenv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

python pmm-framework.py --verbose --client-version=3-dev-latest --pmm-server-password=admin --database pgsql --database ps --database psmdb