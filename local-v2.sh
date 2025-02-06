LINUX_DISTRIBUTION=$(cat /proc/version)
if [[ "$LINUX_DISTRIBUTION" == *"Ubuntu"* ]]; then
    echo "Installing docker on Ubuntu system"
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif [[ "$LINUX_DISTRIBUTION" == *"Red Hat"* ]]; then
    echo "Installing docker on Red Hat system"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
    sudo systemctl --now enable docker
    sudo dnf install -y epel-release > /dev/null
    sudo dnf update -y > /dev/null
    sudo dnf install -y git wget ansible > /dev/null
fi

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
bash ./pmm-framework.sh --download --pdpgsql-version 17 --ps-version 8.0 --mo-version 8.0 --addclient=pdpgsql,1 --addclient=ps,1 --addclient=pxc,1 --mongo-replica-for-backup --pmm2

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
docker restart pxc_container1_8.0