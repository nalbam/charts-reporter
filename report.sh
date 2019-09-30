#!/bin/bash

SHELL_DIR=$(dirname $0)

DEFAULT="nalbam/charts-reporter"
REPOSITORY=${GITHUB_REPOSITORY:-$DEFAULT}

USERNAME=${GITHUB_ACTOR}
REPONAME=$(echo "${REPOSITORY}" | cut -d'/' -f2)

rm -rf ${SHELL_DIR}/target

mkdir -p ${SHELL_DIR}/target/previous
mkdir -p ${SHELL_DIR}/target/versions
mkdir -p ${SHELL_DIR}/target/release

TMP=/tmp/charts

_check_repo() {
    CHART="$1"

    REPO="$(echo $CHART | cut -d'/' -f1)"
    NAME="$(echo $CHART | cut -d'/' -f2)"

    if [ "${REPO}" == "incubator" ]; then
        REPO_URL="https://storage.googleapis.com/kubernetes-charts-incubator"
    elif [ "${REPO}" == "argo" ]; then
        REPO_URL="https://argoproj.github.io/argo-helm"
    elif [ "${REPO}" == "jetstack" ]; then
        REPO_URL="https://charts.jetstack.io"
    elif [ "${REPO}" == "harbor" ]; then
        REPO_URL="https://helm.goharbor.io"
    elif [ "${REPO}" == "monocular" ]; then
        REPO_URL="https://helm.github.io/monocular"
    elif [ "${REPO}" == "gitlab" ]; then
        REPO_URL="https://charts.gitlab.io"
    else
        REPO_URL=""
    fi

    if [ "${REPO_URL}" != "" ]; then
        COUNT=$(helm repo list | awk '{print $1}' | grep "${REPO}" | wc -l | xargs)

        if [ "x${COUNT}" == "x0" ]; then
            helm repo add ${REPO} ${REPO_URL}
        fi
    fi
}

_check_version() {
    CHART="$1"

    REPO="$(echo $CHART | cut -d'/' -f1)"
    NAME="$(echo $CHART | cut -d'/' -f2)"

    touch ${SHELL_DIR}/target/previous/${NAME}
    NOW="$(cat ${SHELL_DIR}/target/previous/${NAME} | xargs)"

    # echo "cat ${TMP} | grep \"${CHART} \""
    # cat ${TMP} | grep "${CHART} "

    NEW="$(cat ${TMP} | grep "${CHART} " | head -1 | awk '{print $2" ("$3")"}' | xargs)"

    printf '# %-40s %-25s %-25s\n' "${CHART}" "${NOW}" "${NEW}"

    printf "${NEW}" > ${SHELL_DIR}/target/versions/${NAME}

    if [ "${NOW}" == "${NEW}" ]; then
        return
    fi

    if [ -z "${SLACK_TOKEN}" ]; then
        return
    fi

    if [ "${REPO}" == "stable" ] || [ "${REPO}" == "incubator" ]; then
        footer="<https://github.com/helm/charts/tree/master/${CHART}|${CHART}>"
    else
        footer="${CHART}"
    fi

    curl -sL opspresso.com/tools/slack | bash -s -- \
        --token="${SLACK_TOKEN}" \
        --username="${REPONAME}" \
        --footer="${footer}" \
        --footer_icon="https://repo.opspresso.com/favicon/helm-152.png" \
        --color="good" \
        --title="helm-chart updated" \
        "\`${CHART}\`\n ${NOW} > ${NEW}"

    echo " slack ${CHART} ${NOW} > ${NEW} "
    echo
}

# previous versions
VERSION=$(curl -s https://api.github.com/repos/${REPOSITORY}/releases/latest | grep tag_name | cut -d'"' -f4 | xargs)
if [ ! -z "${VERSION}" ]; then
    curl -sL https://github.com/${REPOSITORY}/releases/download/${VERSION}/versions.tar.gz | tar xz -C ${SHELL_DIR}/target/previous
fi

# helm init
helm init --client-only
echo

# check repo
while read VAR; do
    _check_repo ${VAR}
done < ${SHELL_DIR}/checklist.txt
echo

# repo update
helm repo update
echo

helm search | awk '{print $1" "$2" "$3}' > ${TMP}

# check versions
while read VAR; do
    _check_version ${VAR}
done < ${SHELL_DIR}/checklist.txt
echo

# package versions
pushd ${SHELL_DIR}/target/versions
tar -czf ../release/versions.tar.gz *
popd
