wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh  > /dev/null

docker network create pmm-qa || true
docker volume create pmm-data

DOCKER_VERSION=perconalab/pmm-server:dev-latest

docker run -d \
    -p 80:80 \
    -p 443:443 \
    -p 9000:9000 \
    --volume pmm-data:/srv \
    --name pmm-server \
    --hostname pmm-server \
    --network pmm-qa \
    --restart always \
    "$DOCKER_VERSION"

LINUX_DISTRIBUTION=$(cat /proc/version)

if [[ "$LINUX_DISTRIBUTION" == *"Ubuntu"* ]]; then
    wget https://raw.githubusercontent.com/percona/pmm-qa/main/pmm-tests/pmm2-client-setup.sh
    chmod +x pmm2-client-setup.sh
    bash -x ./pmm2-client-setup.sh --pmm_server_ip 127.0.0.1 --client_version dev-latest --admin_password admin --use_metrics_mode no
elif [[ "$LINUX_DISTRIBUTION" == *"Red Hat"* ]]; then
    wget https://raw.githubusercontent.com/percona/pmm-qa/main/pmm-tests/pmm2-client-setup-centos.sh
    chmod +x pmm2-client-setup-centos.sh
    bash -x ./pmm2-client-setup-centos.sh --pmm_server_ip 127.0.0.1 --client_version dev-latest --admin_password admin --use_metrics_mode no
fi

git clone https://github.com/percona/pmm-qa.git
cd pmm-qa/
git checkout PMM-13733
cd pmm-tests/
bash ./pmm-framework.sh --addclient=ps,1 --query-source=slowlog --pmm2

cd ../../
git clone https://github.com/percona/pmm-ui-tests.git
cd pmm-ui-tests
git checkout PMM-7-fix-ps-integration
npm ci
apt-get install -y libatspi2.0-0t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libglib2.0-0t64 libasound2t64 libnss3 libnspr4 libxdamage1 libpango-1.0-0 libcairo2 > /dev/null
npx playwright install chromium
npx codeceptjs run -c "pr.codecept.js" --grep "PMM-T1897"







wget https://raw.githubusercontent.com/percona/pmm/refs/heads/v3/get-pmm.sh
chmod +x get-pmm.sh
./get-pmm.sh -n pmm-server -b --network-name pmm-qa --tag "3.0.0" --repo "percona/pmm-server"

sudo percona-release enable pmm3-client release
sudo yum install -y pmm-client

listVar="rs101 rs102 rs103 rs201 rs202 rs203"

for i in $listVar; do
    echo "$i"
    docker exec $i percona-release enable pmm3-client release
    docker exec $i yum install -y pmm-client
    docker exec $i sed -i "s/443/8443/g" /usr/local/percona/pmm/config/pmm-agent.yaml
    docker exec $i cat /usr/local/percona/pmm/config/pmm-agent.yaml
    docker exec $i systemctl restart pmm-agent
done

docker exec pxc_container1_8.0 percona-release enable pmm3-client release
docker exec pxc_container1_8.0 apt install -y pmm-client
docker exec pxc_container1_8.0 sed -i "s/443/8443/g" /usr/local/percona/pmm/config/pmm-agent.yaml
PXC_AGENT_PROCESS_ID=$(docker exec pxc_container1_8.0 ps aux | grep "pmm-agent" | awk -F' ' '{ print $2 }')
docker exec -d pxc_container1_8.0 kill $PXC_AGENT_PROCESS_ID
docker exec -d pxc_container1_8.0 pmm-agent --config-file=/usr/local/percona/pmm/config/pmm-agent.yaml