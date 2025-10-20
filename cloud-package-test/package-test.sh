wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh

echo "Docker Installed"

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
    --publish 443:8443 -p 4647:4647 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:3-dev-latest

git clone https://github.com/Percona-QA/package-testing.git
cd package-testing
git checkout PMM-7-add-valkey-exporter

export PMM_VERSION=3.5.0
export install_repo=experimental
export PS_REPOSITORY=testing
export PSMDB_REPOSITORY=testing

ansible-playbook -vvv --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 playbooks/pmm3-client_integration.yml
