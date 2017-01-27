#!/usr/bin/env bash

VENDOR_HOME=/opt/candy-line

SERVICE_NAME=ltepi2
GITHUB_ID=CANDY-LINE/ltepi2-service
VERSION=2.0.0
BOOT_APN=${BOOT_APN:-umobile.jp}

NODEJS_VERSIONS="v4"

SERVICE_HOME=${VENDOR_HOME}/${SERVICE_NAME}
SRC_DIR="${SRC_DIR:-/tmp/$(basename ${GITHUB_ID})-${VERSION}}"
CANDY_RED=${CANDY_RED:-1}
KERNEL="${KERNEL:-$(uname -r)}"
CONTAINER_MODE=0
if [ "${KERNEL}" != "$(uname -r)" ]; then
  CONTAINER_MODE=1
fi
WELCOME_FLOW_URL=https://git.io/vKhk3
ROUTER_ENABLED=${ROUTER_ENABLED:-1}
LTE_PING_INTERVAL_SEC=${LTE_PING_INTERVAL_SEC:-0}

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
     alert "This script must be run as root"
     exit 1
  fi
}

function test_connectivity {
  curl -s --head --fail -o /dev/null https://github.com 2>&1
  if [ "$?" != 0 ]; then
    alert "Internet connection is required"
    exit 1
  fi
}

function uninstall_if_installed {
  if [ -f "${SERVICE_HOME}/environment" ]; then
    ${SERVICE_HOME}/uninstall.sh > /dev/null
    systemctl daemon-reload
    info "Existing version of ltepi2 has been uninstalled"
    alert "Please reboot the system (enter 'sudo reboot') and run the installation command again"
    exit 1
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

function _ufw_setup {
  info "Configuring ufw..."
  ufw --force disable
  ufw deny in on ppp0
  for n in `ls /sys/class/net`
  do
    if [ "${n}" != "lo" ] && [ "${n}" != "ppp0" ]; then
      ufw allow in on ${n}
      if [ "$?" != "0" ]; then
        err "Failed to configure ufw for the network interface: ${n}"
        exit 4
      fi
    fi
  done
  ufw --force enable
}

function install_ppp_mode {
  if [ "${ROUTER_ENABLED}" != "0" ]; then
    info "*** To be configured for ROUTER MODE ***"
    return
  fi
  info "*** To be configured for PPP MODEM MODE ***"
  info "Installing ufw and ppp..."
  apt-get update -y
  apt-get install -y ufw ppp pppconfig

  cp -f ${SRC_DIR}/systemd/ltepi2.chatscript /etc/chatscripts/ltepi2
  cp -f ${SRC_DIR}/systemd/ltepi2.peers /etc/ppp/peers/ltepi2

  _ufw_setup
}

function install_candy_board {
  RET=`which pip`
  RET=$?
  if [ "${RET}" != "0" ]; then
    info "Installing pip..."
    curl -L https://bootstrap.pypa.io/get-pip.py | /usr/bin/env python
  fi

  pip install --upgrade candy-board-cli
  pip install --upgrade candy-board-amt
}

function install_candy_red {
  if [ "${CANDY_RED}" == "0" ]; then
    return
  fi
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
    info "Installing Node.js..."
    MODEL_NAME=`cat /proc/cpuinfo | grep "model name"`
    if [ "$?" != "0" ]; then
      alert "Unsupported environment"
      exit 1
    fi
    apt-get remove -y nodered nodejs nodejs-legacy npm
    echo ${MODEL_NAME} | grep -o "ARMv6"
    if [ "$?" == "0" ]; then
      cd /tmp
      wget http://node-arm.herokuapp.com/node_archive_armhf.deb
      dpkg -i node_archive_armhf.deb
    else
      curl -sL https://deb.nodesource.com/setup_4.x | sudo bash -
      apt-get install -y nodejs
    fi
  fi
  info "Installing dependencies..."
  apt-get install -y python-dev python-rpi.gpio bluez libudev-dev
  cd ~
  npm cache clean
  info "Installing CANDY-RED..."
  WELCOME_FLOW_URL=${WELCOME_FLOW_URL} NODE_OPTS=--max-old-space-size=128 npm install -g --unsafe-perm candy-red
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
  if [ ! -f "${SRC_DIR}/systemd/boot-apn.${BOOT_APN}.json" ]; then
    err "Invalid BOOT_APN value => ${BOOT_APN}"
    exit 1
  fi

  LIB_SYSTEMD="$(dirname $(dirname $(which systemctl)))"
  if [ "${LIB_SYSTEMD}" == "/" ]; then
    LIB_SYSTEMD=""
  fi
  LIB_SYSTEMD="${LIB_SYSTEMD}/lib/systemd"

  mkdir -p ${SERVICE_HOME}
  cp -f ${SRC_DIR}/systemd/boot-apn.${BOOT_APN}.json ${SERVICE_HOME}/boot-apn.json
  cp -f ${SRC_DIR}/systemd/boot-ip.*.json ${SERVICE_HOME}
  cp -f ${SRC_DIR}/systemd/environment.txt ${SERVICE_HOME}/environment
  sed -i -e "s/%VERSION%/${VERSION//\//\\/}/g" ${SERVICE_HOME}/environment
  sed -i -e "s/%ROUTER_ENABLED%/${ROUTER_ENABLED//\//\\/}/g" ${SERVICE_HOME}/environment
  sed -i -e "s/%LTE_PING_INTERVAL_SEC%/${LTE_PING_INTERVAL_SEC//\//\\/}/g" ${SERVICE_HOME}/environment
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

  install -o root -g root -D -m 755 ${SRC_DIR}/uninstall.sh ${SERVICE_HOME}/uninstall.sh

  info "${SERVICE_NAME} service has been installed"
  REBOOT=1
}

function teardown {
  [ "${DEBUG}" ] || rm -fr ${SRC_DIR}
  if [ "${CONTAINER_MODE}" == "0" ] && [ "${REBOOT}" == "1" ]; then
    alert "*** Please reboot the system (enter 'sudo reboot') ***"
  fi
}

function package {
  rm -f $(basename ${GITHUB_ID})-*.tgz
  # http://unix.stackexchange.com/a/9865
  COPYFILE_DISABLE=1 tar --exclude="./.*" --exclude=Makefile -zcf $(basename ${GITHUB_ID})-${VERSION}.tgz *
}

# main
if [ "$1" == "pack" ]; then
  package
  exit 0
fi
assert_root
test_connectivity
uninstall_if_installed
setup
install_candy_board
install_candy_red
install_service
install_ppp_mode
teardown
