wget https://raw.githubusercontent.com/peterSirotnak/percona-support-scripts/refs/heads/main/install_docker.sh
chmod +x install_docker.sh
./install_docker.sh

echo "Docker Installed"

docker rm -f $(docker ps -aq)
docker volume rm $(docker volume ls -q)
docker rmi -f $(docker images -q)
docker system prune -a --volumes -f

sudo docker rm -f watchtower
sudo docker rm -f pmm-server
sudo docker volume rm pmm-volume

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
    --publish 80:8080 --publish 443:8443 -p 4647:4647 \
    --volume pmm-volume:/srv \
    --name pmm-server \
	perconalab/pmm-server:3-dev-latest

#almalinux/10-base:10
#oraclelinux:10

export DOCKER_TAG="oraclelinux:10"

cat > test.sh <<'EOF'
#!/bin/bash
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "Cannot detect distribution (no /etc/os-release)"
  exit 1
fi

# Normalize to lowercase
distro_id="${ID,,}"          # e.g. "rocky", "ubuntu", "debian"
distro_like="${ID_LIKE,,}"   # e.g. "rhel fedora", "debian"

echo "Detected distribution: ID=${distro_id}  ID_LIKE=${distro_like}"

# Helper predicates
is_debian_like() { [[ "$distro_id" == "debian" || "$distro_id" == "ubuntu" || "$distro_like" == *"debian"* ]]; }
is_rhel_like()   { [[ "$distro_id" =~ ^(rhel|centos|rocky|almalinux|fedora|ol|oracle)$ || "$distro_like" == *"rhel"* || "$distro_like" == *"fedora"* ]]; }

if is_debian_like; then
	apt-get update
    apt-get install -y apt-transport-https ca-certificates ansible git wget iproute
elif is_rhel_like; then
    dnf update -y > /dev/null
    dnf install -y git wget ansible-core iproute
fi

cat >/usr/local/bin/sudo <<'SH'
#!/bin/sh
exec "$@"
SH
chmod +x /usr/local/bin/sudo

git clone https://github.com/Percona-QA/package-testing.git
cd package-testing
git checkout PMM-7-rhel-10-arm

export PMM_SERVER_IP=pmm-server

ansible-playbook -vvv --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 playbooks/pmm3-client_integration.yml
tail -f /dev/null
EOF

# Make script executable
chmod +x test.sh

# Step 2: Run container with test.sh as entrypoint
docker run --detach --rm \
   --network="pmm-network" \
  -v $(pwd)/test.sh:/test.sh \
  --entrypoint /test.sh \
  rockylinux:9