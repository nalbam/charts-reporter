#!/bin/bash

SHELL_DIR=$(dirname $0)

USERNAME=${1:-nalbam}
REPONAME=${2:-charts-reporter}

rm -rf target
mkdir -p ${SHELL_DIR}/target
mkdir -p ${SHELL_DIR}/.previous
mkdir -p ${SHELL_DIR}/.versions

check() {
    NAME=$1

    touch ${SHELL_DIR}/.previous/${NAME}

    NOW="$(cat ${SHELL_DIR}/.previous/${NAME} | xargs)"
    NEW="$(helm search "stable/${NAME}" | grep "stable/${NAME}" | head -1 | awk '{print $2" ("$3")"}' | xargs)"

    printf '# %-25s %-20s %-20s\n' "${NAME}" "${NOW}" "${NEW}"

    printf "${NEW}" > ${SHELL_DIR}/.versions/${NAME}

    if [ "${NOW}" != "${NEW}" ]; then
        if [ ! -z ${SLACK_TOKEN} ]; then
            FOOTER="<https://github.com/helm/charts/tree/master/stable/${NAME}|stable/${NAME}>"
            ${SHELL_DIR}/slack.sh --token="${SLACK_TOKEN}" --channel="tools" \
                --emoji=":construction_worker:" --username="charts-reporter" \
                --footer="${FOOTER}" --footer_icon="https://www.helm.sh/assets/images/favicon.png" \
                --color="good" --title="helm-chart updated" "\`${NAME}\` ${NOW} > ${NEW}"
            echo " slack ${NAME} ${NOW} > ${NEW} "
            echo
        fi
    fi
}

# previous versions
VERSION=$(curl -s https://api.github.com/repos/${USERNAME}/${REPONAME}/releases/latest | grep tag_name | cut -d'"' -f4 | xargs)
if [ ! -z ${VERSION} ]; then
    curl -sL https://github.com/${USERNAME}/${REPONAME}/releases/download/${VERSION}/versions.tar.gz | tar xz -C ${SHELL_DIR}/.previous
fi

# helm init
helm init --client-only
echo

# check versions
while read VAR; do
    check ${VAR}
done < ${SHELL_DIR}/checklist.txt
echo

# package versions
pushd .versions
tar -czf ../target/versions.tar.gz *
popd
