#!/bin/bash

VENDOR_HOME=/opt/candy-line

SERVICE_NAME=ltepi2
GITHUB_ID=CANDY-LINE/ltepi2-service
VERSION=1.0.0

NODEJS_VERSIONS="v0.12 v4.3"

SERVICE_HOME=${VENDOR_HOME}/${SERVICE_NAME}
SRC_DIR="${SRC_DIR:-/tmp/ltepi2-service-${VERSION}}"
CANDY_RED=${CANDY_RED:-1}
KERNEL="${KERNEL:-$(uname -r)}"
CONTAINER_MODE=0
if [ "${KERNEL}" != "$(uname -r)" ]; then
  CONTAINER_MODE=1
fi

REBOOT=0

function err {
  echo -e "\033[91m[ERROR] $1\033[0m"
}

function info {
  echo -e "\033[92m[INFO] $1\033[0m"
}

function alert {
  echo -e "\033[93m[ALERT] $1\033[0m"
}

function setup {
  [ "${DEBUG}" ] || rm -fr ${SRC_DIR}
}

function assert_root {
  if [[ $EUID -ne 0 ]]; then
     echo "This script must be run as root"
     exit 1
  fi
}

function uninstall_if_installed {
  if [ -f "${SERVICE_HOME}/environment" ]; then
    ${SERVICE_HOME}/uninstall.sh > /dev/null
    systemctl daemon-reload
    info "Existing version of ltepi2 has been uninstalled"
  fi
}

function download {
  if [ -d "${SRC_DIR}" ]; then
    return
  fi
  cd /tmp
  curl -L https://github.com/${GITHUB_ID}/archive/${VERSION}.tar.gz | tar zx
  if [ "$?" != "0" ]; then
    err "Make sure internet is available"
    exit 1
  fi
}

function install_scripts {
  download
  info "Installing command lines to ${SERVICE_HOME}..."
  install -o root -g root -D -m 755 ${SRC_DIR}/uninstall.sh ${SERVICE_HOME}/uninstall.sh

  REBOOT=1
}

function install_candy_board {
  pip install --upgrade candy-board-cli
  pip install --upgrade candy-board-amt
}

function install_candy_red {
  if [ "${CANDY_RED}" == "0" ]; then
    return
  fi
  info "Installing CANDY RED..."
  NODEJS_VER=`node -v`
  if [ "$?" == "0" ]; then
    for v in ${NODEJS_VERSIONS}
    do
      echo ${NODEJS_VER} | grep -oE "${v/./\\.}\..*"
      if [ "$?" == "0" ]; then
        unset NODEJS_VER
      fi
    done
  else
    NODEJS_VER="N/A"
  fi
  apt-get update -y
  if [ -n "${NODEJS_VER}" ]; then
    MODEL_NAME=`cat /proc/cpuinfo | grep "model name"`
    if [ "$?" != "0" ]; then
      alert "Unsupported environment"
      exit 1
    fi
    apt-get upgrade -y
    apt-get remove -y nodered nodejs nodejs-legacy npm
    echo ${MODEL_NAME} | grep -o "ARMv6"
    if [ "$?" == "0" ]; then
      cd /tmp
      wget http://node-arm.herokuapp.com/node_archive_armhf.deb
      dpkg -i node_archive_armhf.deb
    else
      curl -sL https://deb.nodesource.com/setup_0.12 | sudo bash -
      apt-get install -y nodejs
    fi
  fi
  apt-get install -y python-dev python-rpi.gpio bluez
  cd ~
  NODE_OPTS=--max-old-space-size=128 npm install -g --unsafe-perm candy-red
  REBOOT=1
}

function install_service {
  info "Installing system service ..."
  RET=`systemctl | grep ${SERVICE_NAME}.service | grep -v not-found`
  RET=$?
  if [ "${RET}" == "0" ]; then
    return
  fi
  download

  LIB_SYSTEMD="$(dirname $(dirname $(which systemctl)))"
  if [ "${LIB_SYSTEMD}" == "/" ]; then
    LIB_SYSTEMD=""
  fi
  LIB_SYSTEMD="${LIB_SYSTEMD}/lib/systemd"

  mkdir -p ${SERVICE_HOME}
  cp -f ${SRC_DIR}/systemd/boot-apn.json ${SERVICE_HOME}
  cp -f ${SRC_DIR}/systemd/environment.txt ${SERVICE_HOME}/environment
  sed -i -e "s/%VERSION%/${VERSION//\//\\/}/g" ${SERVICE_HOME}/environment
  FILES=`ls ${SRC_DIR}/systemd/*.sh`
  FILES="${FILES} `ls ${SRC_DIR}/systemd/server_*.py`"
  for f in ${FILES}
  do
    install -o root -g root -D -m 755 ${f} ${SERVICE_HOME}
  done

  cp -f ${SRC_DIR}/systemd/${SERVICE_NAME}.service.txt ${SRC_DIR}/systemd/${SERVICE_NAME}.service
  sed -i -e "s/%VERSION%/${VERSION//\//\\/}/g" ${SRC_DIR}/systemd/${SERVICE_NAME}.service

  install -o root -g root -D -m 644 ${SRC_DIR}/systemd/${SERVICE_NAME}.service ${LIB_SYSTEMD}/system/
  systemctl enable ${SERVICE_NAME}
  info "${SERVICE_NAME} service has been installed"
  REBOOT=1
}

function teardown {
  [ "${DEBUG}" ] || rm -fr ${SRC_DIR}
  if [ "${CONTAINER_MODE}" == "0" ] && [ "${REBOOT}" == "1" ]; then
    alert "*** Please shutdown the system then restart! (enter 'sudo shutdown -h now' first) ***"
  fi
}

function package {
  rm -f ltepi2-*.tgz
  # http://unix.stackexchange.com/a/9865
  COPYFILE_DISABLE=1 tar --exclude="./.*" --exclude=Makefile -zcf $(basename ${GITHUB_ID})-${VERSION}.tgz *
}

if [ "$1" == "pack" ]; then
  package
  exit 0
fi

# main
assert_root
uninstall_if_installed
setup
install_scripts
install_candy_board
install_candy_red
install_service
teardown
