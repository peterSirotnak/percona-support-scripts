export PODMAN_IGNORE_CGROUPSV1_WARNING=1

podman rm -f pmm-server
podman rm -f watchtower
podman volume remove pmm-data

podman network create pmm-network

podman volume create pmm-data

podman run -d \
                --rm --replace=true \
                -p 80:8080/tcp -p 443:8443/tcp \
                --name pmm-server \
                --net=pmm-network \
                -e PMM_WATCHTOWER_HOST=http://watchtower:8080 \
                -e PMM_WATCHTOWER_TOKEN=testUpgradeToken \
                -e PMM_HTTP_PORT=80 \
                -e PMM_PUBLIC_PORT=443 \
                --cap-add=net_admin,net_raw \
                --userns=keep-id:uid=1000,gid=1000 \
                --ulimit=host \
                -v pmm-data:/srv \
                docker.io/perconalab/pmm-server-fb:PR-3652-13c00dd

podman run -d \
                --rm --replace=true \
                --name watchtower \
                -e WATCHTOWER_DEBUG=1 \
                -e WATCHTOWER_HTTP_API_TOKEN=testUpgradeToken \
                -e WATCHTOWER_HTTP_API_UPDATE=1 \
                -e WATCHTOWER_NO_RESTART=1 \
                -v ${XDG_RUNTIME_DIR}/podman/podman.sock:/var/run/docker.sock \
                --net=pmm-network \
                --cap-add=net_admin,net_raw \
                docker.io/perconalab/watchtower:PMM-13202-fix-double-unlock
