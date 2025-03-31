wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh
sudo docker rm -f watchtower
sudo docker rm -f pmm-server
sudo docker rm -f external-clickhouse

sudo docker network create pmm-network
sudo docker volume create pmm-volume

sudo docker run --detach --restart always \
	--network="pmm-network" \
	-e WATCHTOWER_DEBUG=1 \
	-e WATCHTOWER_HTTP_API_TOKEN=testUpgradeToken \
	-e WATCHTOWER_HTTP_API_UPDATE=1 \
	--volume /var/run/docker.sock:/var/run/docker.sock \
	--name watchtower \
	perconalab/watchtower:latest

docker run --detach --rm --network="pmm-network" \
    -e CLICKHOUSE_DB=pmm \
    -e CLICKHOUSE_USER=pmm \
    -e CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1 \
    -e CLICKHOUSE_PASSWORD=pmm_password \
    --name external-clickhouse \
    clickhouse/clickhouse-server:latest

sleep 10

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
    -e PMM_CLICKHOUSE_ADDR=external-clickhouse:9000 \
    -e PMM_CLICKHOUSE_DATABASE=pmm \
    -e PMM_CLICKHOUSE_USER=pmm \
    -e PMM_CLICKHOUSE_PASSWORD=pmm_password \
    -e PMM_DISABLE_BUILTIN_CLICKHOUSE=1 \
    --publish 80:8080 --publish 443:8443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server-fb:PR-3847-21bf6e0
