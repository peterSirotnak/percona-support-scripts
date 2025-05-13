wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh  > /dev/null
docker rm -f pmm-server
docker volume rm pmm-volume
docker rm -f external-clickhouse
docker rm -f watchtower
docker network create pmm-qa

docker volume create pmm-volume
docker volume create clickhouse-volume

docker run -d \
    --name external-clickhouse \
    --network="pmm-qa" \
    -e CLICKHOUSE_DB=pmm \
    -e CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1 \
    --health-cmd="wget --spider -q localhost:8123/ping" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --volume clickhouse-volume:/srv \
    clickhouse/clickhouse-server:latest

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
    -e PMM_DEV_PERCONA_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PERCONA_TEST_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PMM_DEV_PORTAL_URL=https://portal-dev.percona.com \
    -e PMM_DEV_PERCONA_PLATFORM_PUBLIC_KEY=RWTkF7Snv08FCboTne4djQfN5qbrLfAjb8SY3/wwEP+X5nUrkxCEvUDJ \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_CLICKHOUSE_ADDR=external-clickhouse:9000 \
    -e PMM_CLICKHOUSE_DATABASE=pmm \
    -e PMM_ENABLE_TELEMETRY=0 \
    -e PMM_DEV_UPDATE_DOCKER_IMAGE=perconalab/pmm-server:3-dev-latest \
    --publish 80:8080 --publish 443:8443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
    percona/pmm-server:3.1.0