#!/bin/bash

SHELL_DIR=$(dirname $0)

USERNAME=${CIRCLE_PROJECT_USERNAME:-nalbam}
REPONAME=${CIRCLE_PROJECT_REPONAME:-charts-reporter}

rm -rf ${SHELL_DIR}/target
mkdir -p ${SHELL_DIR}/target
mkdir -p ${SHELL_DIR}/.previous
mkdir -p ${SHELL_DIR}/.versions

check() {
    NAME=$1

    touch ${SHELL_DIR}/.previous/${NAME}

    NOW="$(cat ${SHELL_DIR}/.previous/${NAME} | xargs)"
    NEW="$(helm search "stable/${NAME}" | grep "stable/${NAME}" | head -1 | awk '{print $2" ("$3")"}' | xargs)"

    printf '# %-25s %-25s %-25s\n' "${NAME}" "${NOW}" "${NEW}"

    printf "${NEW}" > ${SHELL_DIR}/.versions/${NAME}

    if [ "${NOW}" == "${NEW}" ]; then
        return
    fi

    if [ -z ${SLACK_TOKEN} ]; then
        return
    fi

    FOOTER="<https://github.com/helm/charts/tree/master/stable/${NAME}|stable/${NAME}>"

    curl -sL opspresso.com/tools/slack | bash -s -- \
        --token="${SLACK_TOKEN}" --emoji=":construction_worker:" --username="${REPONAME}" \
        --footer="${FOOTER}" --footer_icon="https://repo.opspresso.com/favicon/helm-152.png" \
        --color="good" --title="helm-chart updated" "\`${NAME}\` ${NOW} > ${NEW}"

    echo " slack ${NAME} ${NOW} > ${NEW} "
    echo
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
