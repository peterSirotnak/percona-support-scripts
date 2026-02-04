wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh  > /dev/null
docker rmi -f $(docker images -q)
docker system prune -a --volumes -f

docker rm -f $(docker ps -aq)
docker volume rm $(docker volume ls -q)

sudo docker rm -f watchtower
sudo docker rm -f pmm-server
sudo docker volume rm pmm-volume

sudo docker network create pmm-qa

sudo docker run --detach --restart always \
	--network="pmm-qa" \
	-e WATCHTOWER_DEBUG=1 \
	-e WATCHTOWER_HTTP_API_TOKEN=testUpgradeToken \
	-e WATCHTOWER_HTTP_API_UPDATE=1 \
	--volume /var/run/docker.sock:/var/run/docker.sock \
	--name watchtower \
	perconalab/watchtower:dev-latest

sleep 5

export PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

sudo docker run --detach --restart always \
    --network="pmm-qa" \
    -e PMM_DEBUG=1 \
    -e PMM_DEV_PORTAL_URL=https://portal-dev.percona.com \
    -e PMM_DEV_PERCONA_PLATFORM_PUBLIC_KEY=RWTkF7Snv08FCboTne4djQfN5qbrLfAjb8SY3/wwEP+X5nUrkxCEvUDJ \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_DEV_PERCONA_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PERCONA_TEST_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_DEV_UPDATE_DOCKER_IMAGE=perconalab/pmm-server:3-dev-latest \
    -e PMM_ENABLE_NOMAD=1 \
    -e PMM_PUBLIC_ADDRESS=$PUBLIC_IP \
    -e PMM_ENABLE_NOMAD=1 \
    -e PMM_ENABLE_TELEMETRY=0 \
    --publish 80:8080 --publish 443:8443 -p 4647:4647 \
    --volume pmm-volume:/srv \
    --name pmm-server \
        perconalab/pmm-server:3.6.0-rc

rm -fr qa-integration
git clone https://github.com/Percona-Lab/qa-integration.git
cd qa-integration
git checkout main
git pull
cd pmm_qa

echo "Setting docker based PMM clients"
sudo apt install -y python3.12 python3.12-venv
mkdir -m 777 -p /tmp/backup_data
python3 -m venv virtenv
. virtenv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install setuptools

export ADMIN_PASSWORD="Heslo123"
docker exec pmm-server change-admin-password Heslo123

python3 pmm-framework.py \
        --verbosity-level=3 \
        --client-version=https://s3.us-east-2.amazonaws.com/pmm-build-cache/PR-BUILDS/pmm-client/pmm-client-latest-1263.tar.gz \
        --pmm-server-password=Heslo123 \
        --database ps=8.4

wget https://raw.githubusercontent.com/Percona-Lab/qa-integration/refs/heads/v3/pmm_qa/pmm3-client-setup.sh
chmod +x ./pmm3-client-setup.sh
./pmm3-client-setup.sh --pmm_server_ip 35.153.98.163 --client_version 3.0.0 --admin_password i-0a806a240ac977a44 --use_metrics_mode no
cd ../ ../ || true

cd ../
git clone https://github.com/percona/pmm-ui-tests.git
cd pmm-ui-tests
git checkout v3
npm ci
apt-get install -y libatspi2.0-0t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libglib2.0-0t64 libasound2t64 libnss3 libnspr4 libxdamage1 libpango-1.0-0 libcairo2 > /dev/null
npx playwright install chromium
npx codeceptjs run -c "pr.codecept.js" --grep "@pgsm-pmm-integration"

cd ../
git clone https://github.com/percona/pmm-qa.git
cd pmm-qa/e2e_tests/
git checkout main
npm i
npx playwright install-deps
npx playwright install chromium
npx playwright test -g "PMM-T1897"

docker exec ps_pmm_8.4_1 mysql -u root -pGRgrO9301RuF -e 'CREATE DATABASE IF NOT EXISTS T1897'
docker cp ./PMM-T1897.sql ${PDPGSQL_CONTAINER}:/PMM-T1897.sql
docker exec -i ps_pmm_8.4_1 mysql -u root -pGRgrO9301RuF < /${PWD}/testdata/PMM-T1897.sql


npx playwright test --grep @pmm-ps-integration