i=1;

for flag in "$@" 
do
    if [[ $flag =~ "playbook" ]]
    then
        playbook_file=$2
        shift 2
    elif [[ $flag =~ "pmm-version" ]]; then
        pmm_version=$2
        shift 2
    fi
    echo "Playbook file is: $playbook_file"
    echo "PMM Version is: $pmm_version"
done

os_distribution=$(cat /etc/*-release | grep "^NAME" | awk -F '=' '{print $2}')

if [[ $os_distribution =~ "Ubuntu" ]]
then
  chmod +x install-dependencies-ubuntu.sh
  ./install-dependencies-ubuntu.sh
fi

sudo docker compose -f docker-compose-pmm-server-basic.yml up -d

export ADMIN_PASSWORD=admin
export PMM_SERVER_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pmm-server)
export PMM_VERSION=$pmm_version

git clone https://github.com/Percona-QA/package-testing.git

ansible-playbook --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 package-testing/playbooks/$playbook_file.yml