#!/bin/bash
set -eu

USERNAME=admin
HOST=${NEXUS_HOST:-localhost:8081}
PASSWORD=${NEXUS_AUTHORIZATION}
ANONYMOUS_ACCESS=${ENABLE_ANONYMOUS_ACCESS:-false}
NEXUS_BASE_DIR="/opt/sonatype/nexus"
SETUP_DIR="${NEXUS_BASE_DIR}/setup"
declare -a SCRIPT_LIST

echo "post start script running, waiting for nexus (http://$HOST) to be available..."
echo 
until curl --output /dev/null --silent --head --fail http://$HOST/; do
  printf "."
  sleep 5
done

function die() {
    echo "ERROR: $@" 1>&2
    exit 1
}

function createOrUpdateAndRun() {
    local scriptFile scriptName scriptNameRegex
    scriptFile="${1}.json"
    scriptName="$(basename "${1}")"
    scriptNameRegex=" ${scriptName} "
    if [ "${#SCRIPT_LIST[@]}" = 0 ] || [[ ! " ${SCRIPT_LIST[*]} " =~ ${scriptNameRegex} ]]; then
        echo "Creating ${scriptName} repository script"
        curl --fail -X POST -u ${USERNAME}:${PASSWORD} --header "Content-Type: application/json" "http://${HOST}/service/rest/v1/script/" -d @${scriptFile}
    else
        echo "Updating ${scriptName} repository script"
        curl --fail -X PUT -u ${USERNAME}:${PASSWORD} --header "Content-Type: application/json" "http://${HOST}/service/rest/v1/script/${scriptName}" -d @${scriptFile}
    fi
    echo "Running ${scriptName} repository script"
    curl --fail -X POST -u ${USERNAME}:${PASSWORD} --header "Content-Type: text/plain" "http://${HOST}/service/rest/v1/script/${scriptName}/run"
    echo
}

function setScriptList() {
    # initialising the scripts already present once and assuming that there no duplicate script names in the scripts that follow
    mapfile -t SCRIPT_LIST < <(curl --fail -s -u ${USERNAME}:${PASSWORD} "http://${HOST}/service/rest/v1/script" | grep -oE "\"name\" : \"[^\"]+" | sed 's/"name" : "//')
}

if curl --fail --silent -u ${USERNAME}:${PASSWORD} "http://${HOST}/service/metrics/ping"; then
    echo "Login to nexus succeeded. Password from secret worked."
    setScriptList
else
    die "Login to nexus failed. Check the password form the secret which is stored in NEXUS_AUTHORIZATION variable."
fi

createOrUpdateAndRun "$SETUP_DIR/scripts/clear-default-repositories"

mapfile -t REPOS < <(find "$SETUP_DIR/scripts/repositories" -maxdepth 1 -type f -name "*json*" | sed -e 's/\..*$//')
for repo in "${REPOS[@]}"; do
    createOrUpdateAndRun "${repo}"
done

# create groups last
mapfile -t REPOS < <(find "$SETUP_DIR/scripts/repositories/groups" -maxdepth 1 -type f -name "*json*" | sed -e 's/\..*$//')
for repo in "${REPOS[@]}"; do
    createOrUpdateAndRun "${repo}"
done

if [ "$ANONYMOUS_ACCESS" = false ]; then
  createOrUpdateAndRun "$SETUP_DIR/scripts/disable-anonymous-access"
fi
