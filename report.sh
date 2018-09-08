#!/bin/bash

SHELL_DIR=$(dirname $0)

USERNAME=${1:-nalbam}
REPONAME=${2:-charts-reporter}
GITHUB_TOKEN=${3}

check() {
    NAME=$1

    touch ${SHELL_DIR}/.versions/${NAME}

    NOW=$(cat ${SHELL_DIR}/.versions/${NAME} | xargs)
    NEW=$(helm search "stable/${NAME}" | grep "stable/${NAME}" | head -1 | awk '{print $2}' | xargs)

    printf '# %-25s %-10s %-10s\n' "${NAME}" "${NOW}" "${NEW}"

    if [ "x${NOW}" != "x${NEW}" ]; then
        printf "${NEW}" > ${SHELL_DIR}/.versions/${NAME}

        if [ ! -z ${SLACK_TOKEN} ]; then
            ${SHELL_DIR}/slack.sh --token="${SLACK_TOKEN}" --color="good" --title="helm chart updated" "${NAME} ${NOW} > ${NEW}"
            echo " slack ${NAME} ${NOW} > ${NEW} "
        fi
    fi
}

if [ "${USERNAME}" != "nalbam" ]; then
    if [ ! -z ${GITHUB_TOKEN} ]; then
        git config --global user.name "bot"
        git config --global user.email "ops@nalbam.com"

        echo "# git remote add --track master nalbam github.com/nalbam/charts-reporter"
        git remote add --track master nalbam https://github.com/nalbam/charts-reporter.git

        echo "# git pull nalbam master"
        git pull nalbam master

        echo "# git push github.com/${USERNAME}/${REPONAME} master"
        git push -q https://${GITHUB_TOKEN}@github.com/${USERNAME}/${REPONAME}.git master
    fi
fi

mkdir -p ${SHELL_DIR}/.versions

helm init --client-only
echo

while read VAR; do
    check ${VAR}
done < ${SHELL_DIR}/checklist.txt
