#!/bin/bash

SHELL_DIR=$(dirname $0)

SLACK_TOKEN=${1}

CHANGED=

mkdir -p ${SHELL_DIR}/.versions

check() {
    NAME=$1

    touch ${SHELL_DIR}/.versions/${NAME}

    NOW=$(cat ${SHELL_DIR}/.versions/${NAME} | xargs)
    NEW=$(helm search "stable/${NAME}" | grep "stable/${NAME}" | head -1 | awk '{print $2}' | xargs)

    printf '# %-25s %-10s %-10s\n' "${NAME}" "${NOW}" "${NEW}"

    if [ "x${NOW}" != "x${NEW}" ]; then
        printf "${NEW}" > ${SHELL_DIR}/.versions/${NAME}

        if [ ! -z ${SLACK_TOKEN} ]; then
            ${SHELL_DIR}/slack.sh --token="${SLACK_TOKEN}" --color="good" --title="helm chart updated" ${NAME} ${NOW} > ${NEW}
            echo " slack ${NAME} ${NOW} > ${NEW} "
        fi
    fi
}

helm init --client-only
echo

while read VAR; do
    check ${VAR}
done < ${SHELL_DIR}/checklist.txt
