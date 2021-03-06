#!/usr/bin/env bash

PRODUCT="LTEPi-II Board"
PRODUCT_DIR_NAME="ltepi2"
MODEM_USB_MODE=""
MODEM_SERIAL_PORT=""
DEBUG=""

DHCPCD_CNF="/etc/dhcpcd.conf"
DHCPCD_ORG="/etc/dhcpcd.conf.org_candy"
DHCPCD_TMP="/etc/dhcpcd.conf.org_tmp"

function log {
  logger -t ${PRODUCT_DIR_NAME} $1
  if [ "${DEBUG}" ]; then
    echo ${PRODUCT_DIR_NAME} $1
  fi
}

function wait_for_modem_usb_active {
  MAX=40
  COUNTER=0
  while [ ${COUNTER} -lt ${MAX} ];
  do
    RET=`lsusb | grep 1ecb:0208`
    if [ "$?" == "0" ]; then
      MODEM_USB_MODE="ECM"
      break
    fi
    RET=`lsusb | grep 1ecb:0202`
    if [ "$?" == "0" ]; then
      MODEM_USB_MODE="ACM"
      break
    fi
    sleep 1
    let COUNTER=COUNTER+1
  done
}

function _wait_for_usb_inactive {
  MAX=40
  COUNTER=0
  while [ ${COUNTER} -lt ${MAX} ];
  do
    RET=`lsusb | grep 1ecb:$1`
    if [ "$?" != "0" ]; then
      break
    fi
    sleep 1
    let COUNTER=COUNTER+1
  done
}

function wait_for_modem_usb_acm_inactive {
  _wait_for_usb_inactive "0202"
}

function wait_for_modem_usb_ecm_inactive {
  _wait_for_usb_inactive "0208"
}

function wait_for_modem_usb_inactive {
  MAX=40
  COUNTER=0
  while [ ${COUNTER} -lt ${MAX} ];
  do
    RET=`lsusb | grep 1ecb:0208`
    if [ "$?" != "0" ]; then
      RET=`lsusb | grep 1ecb:0202`
      if [ "$?" != "0" ]; then
        break
      fi
    fi
    sleep 1
    let COUNTER=COUNTER+1
  done
}

function look_for_serial_port {
  MAX=60
  COUNTER=0
  while [ ${COUNTER} -lt ${MAX} ];
  do
    MODEM_SERIAL_PORT=`/usr/bin/env python -c "import candy_board_amt; print(candy_board_amt.SerialPort.resolve_modem_port())"`
    if [ "${MODEM_SERIAL_PORT}" != "None" ]; then
      COUNTER=0
      break
    fi
    sleep 1
    let COUNTER=COUNTER+1
  done
  log "${MODEM_SERIAL_PORT} is selected"
}

function _change_to {
  log "Modifying the USB data connection I/F to $1"
  /usr/bin/env python /opt/candy-line/${PRODUCT_DIR_NAME}/server_main.py ${MODEM_SERIAL_PORT} /var/run/candy-board-service.sock $2
  RET=$?
  if [ "${RET}" == "0" ]; then
    log "Restarting modem..."
  else
    exit ${RET}
  fi
}

function change_to_acm {
  _change_to "ACM" "init_acm"
}

function change_to_ecm {
  _change_to "ECM" "init_ecm"
}

function enable_auto_connect {
  log "Enabling auto-connect mode"
  /usr/bin/env python /opt/candy-line/${PRODUCT_DIR_NAME}/server_main.py ${MODEM_SERIAL_PORT} /var/run/candy-board-service.sock init_autoconn
  RET=$?
  if [ "${RET}" == "1" ]; then
    RET=`uname -r | grep edison`
    RET=$?
    if [ "${RET}" == "0" ]; then
      # Reboot in order to avoid kernel panic
      log "Rebooting..."
      reboot
      exit 0
    fi
    log "Waiting for USB being inactivated"
    wait_for_modem_usb_inactive
  elif [ "${RET}" != "0" ]; then
    exit ${RET}
  fi
}

function wait_for_default_route {
  MAX=60
  COUNTER=0
  while [ ${COUNTER} -lt ${MAX} ];
  do
    RET=`ip route | grep ${IF_NAME}`
    if [ "$?" == "0" ]; then
      break
    fi
    sleep 1
    let COUNTER=COUNTER+1
  done
}

function remove_default_routes {
  for n in `ls /sys/class/net`
  do
    if [ "${n}" != "lo" ] && [ "${n}" != "ppp0" ]; then
      IP=`ip route | grep ${n} | awk '/default/ { print $3 }'`
      if [ -n "${IP}" ]; then
        ip route del default via ${IP}
      fi
    fi
  done
}

function unregister_ftdi_sio {
  if [ -d "/sys/bus/usb/drivers/ftdi_sio" ]; then
    for d in `ls /sys/bus/usb/drivers/ftdi_sio | grep ":"`; do
      echo -n ${d} > /sys/bus/usb/drivers/ftdi_sio/unbind
    done
    modprobe -r ftdi_sio
  fi
}

function reregister_ftdi_sio {
  if [ ! -d "/sys/bus/usb/drivers/ftdi_sio" ]; then
    modprobe ftdi_sio
  fi
}

function register_usbserial {
  # Registering a new id
  if [ -e "/sys/bus/usb-serial/drivers/pl2303" ]; then
    if [ "${MODEM_USB_MODE}" == "ACM" ]; then
      echo "1ecb 0202" > /sys/bus/usb-serial/drivers/pl2303/new_id
    else
      echo "1ecb 0208" > /sys/bus/usb-serial/drivers/pl2303/new_id
    fi
  else
    unregister_ftdi_sio
    if [ "${MODEM_USB_MODE}" == "ACM" ]; then
      modprobe usbserial vendor=0x1ecb product=0x0202
    else
      modprobe usbserial vendor=0x1ecb product=0x0208
    fi
    reregister_ftdi_sio
  fi
}

function modem_on {
  MODEM_ON=1
  RET=`lsusb | grep 1ecb:0208`
  if [ "$?" == "0" ]; then
    MODEM_ON=0
  else
    RET=`lsusb | grep 1ecb:0202`
    if [ "$?" == "0" ]; then
      MODEM_ON=0
    fi
  fi
  if [ "${MODEM_ON}" == "1" ]; then
    log "Turning Modem ON..."
    /opt/candy-line/${PRODUCT_DIR_NAME}/_modem_on.sh > /dev/null 2>&1
    sleep 9
  fi
}

function diagnose_self {
  log "Diagnosing modem..."
  wait_for_modem_usb_active
  if [ -z "${MODEM_USB_MODE}" ]; then
    return
  fi

  if [ "${ROUTER_ENABLED}" == "1" ]; then
    # Use ECM for ROUTER MODE
    if [ "${MODEM_USB_MODE}" == "ACM" ]; then
      MODEM_USB_MODE=""

      look_for_serial_port
      change_to_ecm
      wait_for_modem_usb_acm_inactive
      wait_for_modem_usb_active
      if [ -z "${MODEM_USB_MODE}" ]; then
        return
      fi

      register_usbserial
      look_for_serial_port
      enable_auto_connect
      wait_for_modem_usb_active
      if [ -z "${MODEM_USB_MODE}" ]; then
        return
      fi
    fi
  else
    # Use ACM for PPP MODEM MODE
    if [ "${MODEM_USB_MODE}" == "ECM" ]; then
      MODEM_USB_MODE=""

      register_usbserial
      look_for_serial_port
      change_to_acm
      wait_for_modem_usb_ecm_inactive
      wait_for_modem_usb_active
      if [ -z "${MODEM_USB_MODE}" ]; then
        return
      fi

      register_usbserial
      look_for_serial_port
      wait_for_modem_usb_active
      if [ -z "${MODEM_USB_MODE}" ]; then
        return
      fi
    fi
    # prune all pppd processes prior to starting a new pppd
    poff
    remove_default_routes
    pon ltepi2
  fi
}

# LTE/3G USB Ethernet
function activate_lte {
  if [ -z "${MODEM_USB_MODE}" ]; then
    return
  fi

  log "Activating LTE/3G Module..."
  if [ "${MODEM_USB_MODE}" == "ACM" ]; then
    IF_NAME="ppp0"
  else
    USB_ID=`dmesg | grep "New USB device found, idVendor=1ecb, idProduct=0208" | sed 's/^.*\] //g' | cut -f 1 -d ':' | cut -f 2 -d ' ' | tail -1`
    # when renamed
    IF_NAME=`dmesg | grep "renamed network interface usb1" | sed 's/^.* usb1 to //g' | cut -f 1 -d ' ' | tail -1`
    if [ -z "${IF_NAME}" ]; then
      IF_NAME=`dmesg | grep " ${USB_ID}" | grep "register 'cdc_ether'" | cut -f 2 -d ':' | cut -f 2 -d ' ' | tail -1`
    fi
    if [ -n "${IF_NAME}" ]; then
      ifconfig ${IF_NAME} up
      RET=`which udhcpc`
      RET=$?
      if [ "${RET}" == "0" ]; then
        if [ -f "/var/run/udhcpc-${IF_NAME}.pid" ]; then
          cat "/var/run/udhcpc-${IF_NAME}.pid" | xargs kill -9
        fi
        udhcpc -i ${IF_NAME} -p /var/run/udhcpc-${IF_NAME}.pid -S
      fi
    else
      IF_NAME=""
    fi
  fi
  if [ -n "${IF_NAME}" ]; then
    log "The interface [${IF_NAME}] is up!"
    register_usbserial
    look_for_serial_port
    if [ "${ROUTER_ENABLED}" == "1" ]; then
      wait_for_default_route
    fi
  fi
}

function boot_ip_reset {
  if [ -f "/boot/boot-ip-reset" ]; then
    rm -f "/boot/boot-ip-reset"
    if [ -f "${DHCPCD_ORG}" ]; then
      mv -f "${DHCPCD_ORG}" "${DHCPCD_CNF}"
      log "Rebooting for resetting boot-ip..."
      reboot
    fi
  fi
}

function boot_ip_addr {
  LIST=`ls -1 /boot/boot-ip*.json`
  if [ "$?" == "0" ]; then
    NUM=`ls -1 /boot/boot-ip*.json | wc -l`
    if [ "${NUM}" != "1" ]; then
      log "Skip to configure IP address as more than 2 boot-ip files are found => [${LIST}]"
      unset LIST # not remove boot-ip*.json files
      return
    fi
  else
    return
  fi
  if [ ! -f "${LIST}" ]; then
    log "${LIST} is missing." # this should not happen
    unset LIST
    return
  fi
  SIZE=`ls -lrt ${LIST} | nawk '{print $5}'`
  if [[ "${SIZE}" -gt "1000" ]]; then
    log "Too big to read. Aborted."
    unset LIST # not remove boot-ip*.json files
    return
  fi

  log "Checking /etc/dhcpcd.conf..."
  for p in interface ip_address routers domain_name_servers
  do
    VAL=`/usr/bin/env python -c "with open('${LIST}') as f:import json;print(('${p}=%s') % json.load(f)['${p}'])"`
    if [ "$?" != "0" ]; then
      log "Unexpected format => ${LIST}. Configruation aborted."
      unset LIST # not remove boot-ip*.json files
      return
    fi
    eval ${VAL}
  done

  NUM=`grep -wc "^[^#;]*interface\s*${interface}" "${DHCPCD_CNF}"`
  if [ "${NUM}" == "0" ]; then # update org_candy unless I/F is configured
    cp -f "${DHCPCD_CNF}" "${DHCPCD_ORG}"
  fi

  if [ -f "${DHCPCD_ORG}" ]; then
    rm -f "${DHCPCD_TMP}"
    cp -f "${DHCPCD_ORG}" "${DHCPCD_TMP}"
  else
    log "Static IP is already configured in ${DHCPCD_CNF}"
    return
  fi

  NUM=`grep -wc "^[^#;]*interface\s*${interface}" "${DHCPCD_TMP}"`
  if [ "${NUM}" != "0" ]; then # double-check
    log "Cannot configure IP as static IP is already configured..."
    rm -f "${DHCPCD_ORG}"
    return
  fi

  log "Configuring IP address..."
  echo -e "# Appended by ltepi2-service" >> "${DHCPCD_TMP}"
  echo -e "interface ${interface}" >> "${DHCPCD_TMP}"
  for p in ip_address routers domain_name_servers
  do
    echo -e "static ${p}=${!p}" >> "${DHCPCD_TMP}"
  done
  rm -f "${LIST}"
  if [ ! -f "${LIST}" ]; then
    mv -f ${DHCPCD_TMP} ${DHCPCD_CNF}
    if [ ! -f "${DHCPCD_TMP}" ] && [ -f "${DHCPCD_CNF}" ]; then
      log "Restarting..."
      reboot
    fi
  fi
}

function boot_ip_addr_fin {
  rm -f "${DHCPCD_TMP}"
  if [ -f "${LIST}" ]; then
    rm -f "${LIST}"
  fi
}

# Configuring boot-ip
boot_ip_reset
boot_ip_addr
boot_ip_addr_fin

# start banner
log "Initializing ${PRODUCT}..."
. /opt/candy-line/${PRODUCT_DIR_NAME}/_pin_settings.sh > /dev/null 2>&1
export LED2

modem_on
diagnose_self
activate_lte

# end banner
if [ "${MODEM_USB_MODE}" == "ECM" ] || [ "${MODEM_USB_MODE}" == "ACM" ]; then
  log "${PRODUCT} is initialized successfully!"
  /usr/bin/env python /opt/candy-line/${PRODUCT_DIR_NAME}/server_main.py ${MODEM_SERIAL_PORT} ${IF_NAME}
else
  log "${PRODUCT} is not initialized... Silently terminated"
fi
