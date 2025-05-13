wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh

sudo docker rm -f watchtower
sudo docker rm -f pmm-server
sudo docker rm -f external-postgresql

sudo docker network create pmm-network
sudo docker volume create pmm-volume

docker run --detach --rm --network="pmm-network" \
    -e POSTGRES_PASSWORD=pmm_password \
    --name external-postgresql \
    perconalab/percona-distribution-postgresql:17

sudo docker run --detach --restart always \
	--network="pmm-network" \
	-e WATCHTOWER_DEBUG=1 \
	-e WATCHTOWER_HTTP_API_TOKEN=testUpgradeToken \
	-e WATCHTOWER_HTTP_API_UPDATE=1 \
	--publish 5432:5432 \
	--volume /var/run/docker.sock:/var/run/docker.sock \
	--name watchtower \
	perconalab/watchtower:latest

sleep 30

sudo docker run --detach --restart always \
    --network="pmm-network" \
    -e PMM_DEBUG=1 \
    -e PMM_DEV_PORTAL_URL=https://portal-dev.percona.com \
    -e PMM_DEV_PERCONA_PLATFORM_PUBLIC_KEY=RWTkF7Snv08FCboTne4djQfN5qbrLfAjb8SY3/wwEP+X5nUrkxCEvUDJ \
    -e PMM_DEV_PERCONA_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PERCONA_TEST_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_ENABLE_TELEMETRY=0 \
    -e PMM_POSTGRES_DBNAME=postgres \
    -e PMM_POSTGRES_ADDR=external-postgresql:5432 \
    -e PMM_POSTGRES_USERNAME=postgres \
    -e PMM_POSTGRES_DBPASSWORD=pmm_password \
    -e PMM_DISABLE_BUILTIN_POSTGRES=true \
    -e GF_DATABASE_URL=postgres://postgres:pmm_password@external-postgresql:5432/postgres \
    --publish 80:8080 --publish 443:8443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:3-dev-latest
