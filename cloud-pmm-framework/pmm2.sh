wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh  > /dev/null
docker rm -f $(docker ps -a -q)
docker system prune -a --volumes --force
sudo docker rm -f pmm-server
sudo docker volume rm -f pmm-volume

sudo docker volume create pmm-volume
sudo docker network create pmm-qa

docker run -d \
    -p 80:80 \
    -p 443:443 \
    -p 9000:9000 \
    --volume pmm-volume:/srv \
    --name pmm-server \
    --network pmm-qa \
    --restart always \
    -e PMM_DEBUG=1 \
    -e PERCONA_TEST_TELEMETRY_INTERVAL=10s \
    -e PERCONA_TEST_PLATFORM_PUBLIC_KEY=RWTkF7Snv08FCboTne4djQfN5qbrLfAjb8SY3/wwEP+X5nUrkxCEvUDJ \
    -e PERCONA_PORTAL_URL=https://portal-dev.percona.com  \
    -e PERCONA_TEST_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    perconalab/pmm-server:2.44.1

set -o errexit
set -o xtrace
export PATH=$PATH:/usr/sbin
export PMM_CLIENT_VERSION=2.44.1
LINUX_DISTRIBUTION=$(cat /proc/version)

if [[ "$LINUX_DISTRIBUTION" == *"Ubuntu"* ]]; then
    wget https://raw.githubusercontent.com/percona/pmm-qa/v2/pmm-tests/pmm2-client-setup.sh
    chmod +x pmm2-client-setup.sh
    bash -x ./pmm2-client-setup.sh --pmm_server_ip 127.0.0.1 --client_version dev-latest --admin_password admin --use_metrics_mode no
elif [[ "$LINUX_DISTRIBUTION" == *"Red Hat"* ]]; then
    wget https://raw.githubusercontent.com/percona/pmm-qa/v2/pmm-tests/pmm2-client-setup-centos.sh
    chmod +x pmm2-client-setup-centos.sh
    bash -x ./pmm2-client-setup-centos.sh --pmm_server_ip 127.0.0.1 --client_version dev-latest --admin_password admin --use_metrics_mode no
fi

wget https://raw.githubusercontent.com/percona/pmm-qa/refs/heads/PMM-fix-v2-setup/pmm-tests/pmm-framework.sh
chmod +x ./pmm-framework.sh
bash ./pmm-framework.sh --download --pdpgsql-version 17 --ps-version 8.0 --mo-version 8.0 --addclient=pdpgsql,1 --addclient=ps,1 --mongo-replica-for-backup --pmm2
    --download \
    --pmm2 \
    --dbdeployer \
    --run-load-pmm2 \
    --pmm2-server-ip=127.0.0.1 \
    --mongo-replica-for-backup

echo "Waiting for four minutes to get data!"
sleep 180

wget https://raw.githubusercontent.com/percona/pmm/refs/heads/v3/get-pmm.sh
chmod +x get-pmm.sh
./get-pmm.sh -n pmm-server -b --network-name pmm-qa --tag "PR-4065-be7b215" --repo "perconalab/pmm-server-fb"

sudo percona-release enable pmm3-client experimental
sudo apt install -y pmm-client
