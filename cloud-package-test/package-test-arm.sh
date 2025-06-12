sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings

wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh

sudo docker network create pmm-network
sudo docker volume create pmm-volume

sudo docker run --detach --restart always \
    --network="pmm-network" \
    -e PMM_DEBUG=1 \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_DEV_UPDATE_DOCKER_IMAGE=perconalab/pmm-server:3-dev-latest \
    -e PMM_ENABLE_NOMAD=1 \
    -e PMM_PUBLIC_ADDRESS=127.0.0.1 \
    --publish 80:8080 --publish 443:8443 -p 4647:4647 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:202502200909-arm64

git clone https://github.com/Percona-QA/package-testing.git
cd package-testing
git checkout v3

export PMM_VERSION=3.2.0
export PMM_SERVER_IP=127.0.0.1

ansible-playbook -vvv --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 playbooks/pmm3-client_integration.yml