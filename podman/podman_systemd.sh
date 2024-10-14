distribution_name=$(cat /etc/os-release | grep "^NAME=")

if [[ $distribution_name =~ "Rocky Linux" ]]; then
    echo "Installing Podman on Rocky linux"
    sudo dnf -y install podman
fi

#sudo apt-get update
#sudo apt-get install -y podman


sudo sysctl net.ipv4.ip_unprivileged_port_start=80

podman rm -f pmm-server
podman rm -f watchtower
podman network create pmm-network

mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/watchtower.service <<EOF
[Unit]
Description=watchtower
Wants=network-online.target
After=network-online.target
After=nss-user-lookup.target nss-lookup.target
After=time-sync.target

[Service]
Restart=on-failure
RestartSec=20

ExecStart=/bin/bash -l -c '/usr/bin/podman run --rm --replace=true --name watchtower \
    --security-opt label=disable \
    -v $XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock \
    -e WATCHTOWER_HTTP_API_UPDATE=1 \
    -e WATCHTOWER_HTTP_API_TOKEN=123 \
    -e WATCHTOWER_NO_RESTART=1 \
    -e WATCHTOWER_DEBUG=1 \
    --net pmm-network \
    --cap-add=net_admin,net_raw \
    docker.io/perconalab/watchtower:PMM-13202-fix-double-unlock>/tmp/options12.debug'

ExecStop=/usr/bin/podman stop -t 10 %N

[Install]
WantedBy=default.target
EOF

systemctl --user enable --now watchtower

attempt=0
while [ $attempt -le 20 ]; do
    attempt=$(( $attempt + 1 ))
    echo "Waiting for watchtower to be up (attempt: $attempt)..."
    result=$(systemctl --user status watchtower)
    if grep "he HTTP API is enabled at :8080." <<< $result ; then
        echo "watchtower is ready!"
        break
    fi
    sleep 5
done;

mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/pmm-server.service <<EOF
[Unit]
Description=pmm-server
Wants=network-online.target
After=network-online.target
After=nss-user-lookup.target nss-lookup.target
After=time-sync.target

[Service]

Restart=on-failure
RestartSec=20

ExecStart=/bin/bash -l -c '/usr/bin/podman run --volume ~/.config/systemd/user/:/home/pmm/update/ \
		--rm --replace=true \
		--name pmm-server \
		-e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
		-e PMM_WATCHTOWER_TOKEN=123 \
		--net pmm-network \
		--cap-add=net_admin,net_raw \
		-p 80:8080/tcp -p 443:8443/tcp \
		--ulimit=host \
		docker.io/perconalab/pmm-server-fb:PR-3652-13c00dd>/tmp/options.debug'

ExecStop=/usr/bin/podman stop -t 10 %N

[Install]
WantedBy=default.target

EOF

systemctl --user enable --now pmm-server

export CONTAINER_NAME="pmm-server"
export LOGS="pmm-managed entered RUNNING state"
attempt=0
while [ $attempt -le 20 ]; do
    attempt=$(( $attempt + 1 ))
    echo "Waiting for ${CONTAINER_NAME} to be up (attempt: $attempt)..."
    result=$(systemctl --user status ${CONTAINER_NAME})
    if grep "${LOGS}" <<< $result ; then
        echo "${CONTAINER_NAME} is ready!"
        break
    fi
    sleep 5
done;
