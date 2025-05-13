wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh  > /dev/null
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
	perconalab/watchtower:latest

sleep 10

sudo docker run --detach --restart always \
    --network="pmm-qa" \
    -e PMM_DEBUG=1 \
    -e PMM_DEV_PORTAL_URL=https://portal-dev.percona.com \
    -e PMM_DEV_PERCONA_PLATFORM_PUBLIC_KEY=RWTkF7Snv08FCboTne4djQfN5qbrLfAjb8SY3/wwEP+X5nUrkxCEvUDJ \
    -e PMM_DEV_PERCONA_PLATFORM_ADDRESS=https://check-dev.percona.com:443 \
    -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
    -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
    -e PMM_ENABLE_UPDATES=1 \
    -e PMM_DEV_UPDATE_DOCKER_IMAGE=perconalab/pmm-server:3-dev-latest \
    --publish 80:8080 --publish 443:8443 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:3-dev-latest

git clone https://github.com/Percona-Lab/qa-integration.git
cd qa-integration
git checkout PMM-7-install-pmm-client-ansible
cd pmm_qa

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
        --verbosity-level=5 \
        --client-version=pmm3-latest \
        --database ps=8.4

wget https://raw.githubusercontent.com/Percona-Lab/qa-integration/refs/heads/v3/pmm_qa/pmm3-client-setup.sh
./pmm3-client-setup.sh --pmm_server_ip 127.0.0.1 --client_version https://s3.us-east-2.amazonaws.com/pmm-build-cache/PR-BUILDS/pmm-client/pmm-client-PR-3883-dd79008.tar.gz --admin_password admin --use_metrics_mode no
cd ../ ../ || true

cd ../
git clone https://github.com/percona/pmm-ui-tests.git
cd pmm-ui-tests
git checkout PMM-12153
npm ci
apt-get install -y libatspi2.0-0t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libglib2.0-0t64 libasound2t64 libnss3 libnspr4 libxdamage1 libpango-1.0-0 libcairo2 > /dev/null
npx playwright install chromium
npx codeceptjs run -c "pr.codecept.js" --grep "PMM-T9999"
