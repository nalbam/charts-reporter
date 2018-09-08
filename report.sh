#!/bin/bash

SHELL_DIR=$(dirname $0)

USERNAME=${1:-nalbam}
REPONAME=${2:-charts-reporter}
GITHUB_TOKEN=${3}

mkdir -p ${SHELL_DIR}/.previous
mkdir -p ${SHELL_DIR}/.versions
mkdir -p ${SHELL_DIR}/target

check() {
    NAME=$1

    touch ${SHELL_DIR}/.previous/${NAME}
    touch ${SHELL_DIR}/.versions/${NAME}

    NOW=$(cat ${SHELL_DIR}/.previous/${NAME} | xargs)
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

# previous versions
VERSION=$(curl -s https://api.github.com/repos/${REPO}/${NAME}/releases/latest | grep tag_name | cut -d'"' -f4 | xargs)
if [ ! -z ${VERSION} ]; then
    curl -sL https://github.com/${REPO}/${NAME}/releases/download/${VERSION}/versions.tar.gz | tar xz -C ${SHELL_DIR}/.previous
    ls -al ${SHELL_DIR}/.previous
    echo
fi

VERSION=$(echo ${VERSION:-v0.0.0} | perl -pe 's/^(([v\d]+\.)*)(\d+)(.*)$/$1.($3+1).$4/e')
printf "${VERSION}" > target/VERSION
cat target/VERSION
echo

# helm init
helm init --client-only
echo

# check versions
while read VAR; do
    check ${VAR}
done < ${SHELL_DIR}/checklist.txt

# package versions
pushd .versions
tar -czf ../target/versions.tar.gz *
popd
