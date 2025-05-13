wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh

sudo docker network create pmm-qa
sudo docker volume create pmm-volume

sudo docker run --detach --restart always \
    --network="pmm-qa" \
    -e PMM_DEBUG=1 \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_DEV_UPDATE_DOCKER_IMAGE=perconalab/pmm-server:3-dev-latest \
    --publish 80:80 --publish 443:443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:dev-latest

git clone https://github.com/Percona-QA/package-testing.git
cd package-testing
git checkout PMM-7-fix-v2-package-tests

export PMM_VERSION=2.44.0
export PMM_SERVER_IP=127.0.0.1

ansible-playbook -vvvvv --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 playbooks/pmm2-client_integration_upgrade_custom_path.yml