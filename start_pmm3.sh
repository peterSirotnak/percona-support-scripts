sudo docker compose up -d --quiet-pull

for flag in "$@"
do
    if [[ $flag =~ "repository" ]]
    then
        PMM_REPOSITORY=$2
        shift 2
    fi
done

echo "PMM Repository is: $PMM_REPOSITORY"

if [ -z "$PMM_REPOSITORY" ]; then
    sudo docker exec pmm-server sed -i'' -e "s^/release/^/$PMM_REPOSITORY/^" /etc/yum.repos.d/pmm2-server.repo
    sudo docker exec pmm-server percona-release enable-only pmm2-client "$PMM_REPOSITORY"
fi