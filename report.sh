#!/bin/bash

SHELL_DIR=$(dirname $0)

DEFAULT="nalbam/charts-reporter"
REPOSITORY=${GITHUB_REPOSITORY:-$DEFAULT}

USERNAME=${GITHUB_ACTOR}
REPONAME=$(echo "${REPOSITORY}" | cut -d'/' -f2)

CHARTS=${SHELL_DIR}/target/charts.txt

_init() {
    rm -rf ${SHELL_DIR}/target

    mkdir -p ${SHELL_DIR}/target
    mkdir -p ${SHELL_DIR}/versions

    cp -rf ${SHELL_DIR}/versions ${SHELL_DIR}/target/
}

_load() {
    helm version

    helm search hub -o json | jq '.[] | "\"\(.url)\" \(.version) \(.app_version)"' -r > ${CHARTS}
}

_check_version() {
    CHART="$1"

    REPO="$(echo ${CHART} | cut -d'/' -f1)"
    NAME="$(echo ${CHART} | cut -d'/' -f2)"

    touch ${SHELL_DIR}/versions/${NAME}
    NOW="$(cat ${SHELL_DIR}/versions/${NAME} | xargs)"

    NEW="$(cat ${CHARTS} | grep "/${CHART}\"" | awk '{print $2" ("$3")"}' | xargs)"

    printf '# %-40s %-25s %-25s\n' "${CHART}" "${NOW}" "${NEW}"

    printf "${NEW}" > ${SHELL_DIR}/versions/${NAME}

    if [ "${NOW}" == "${NEW}" ]; then
        return
    fi

    if [ -z "${SLACK_TOKEN}" ]; then
        return
    fi

    if [ "${REPO}" == "stable" ] || [ "${REPO}" == "incubator" ]; then
        FOOTER="<https://github.com/helm/charts/tree/master/${CHART}|${CHART}>"
    else
        FOOTER="${CHART}"
    fi

    curl -sL opspresso.github.io/tools/slack.sh | bash -s -- \
        --token="${SLACK_TOKEN}" --username="${REPONAME}" --color="good" \
        --footer="${FOOTER}" --footer_icon="https://opspresso.github.io/tools/favicon/helm.png" \
        --title="helm-chart updated" "\`${CHART}\`\n ${NOW} > ${NEW}"

    echo " slack ${CHART} ${NOW} > ${NEW} "
    echo
}

_run() {
    _init

    _load

    printf '# %-40s %-25s %-25s\n' "NAME" "NOW" "NEW"

    # check versions
    while read VAR; do
        _check_version ${VAR}
    done < ${SHELL_DIR}/checklist.txt
    echo

    # commit message
    printf "$(date +%Y%m%d-%H%M)" > ${SHELL_DIR}/target/commit_message.txt
}

_run
