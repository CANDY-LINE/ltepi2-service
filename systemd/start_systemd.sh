#!/usr/bin/env bash

PRODUCT="LTEPi-II Board"
MODEM_USB_MODE=""
MODEM_SERIAL_PORT=""

function wait_for_modem_usb_active {
  MAX=20
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
    sleep 0.5
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
}

function try_to_change_usb_data_conn {
  # Change to ECM
  logger -s "Modifying the USB data connection I/F to ECM"
  /usr/bin/env python /opt/candy-line/ltepi2/server_main.py ${MODEM_SERIAL_PORT} /var/run/candy-board-service.sock init
  logger -s "*** Rebooting... ***"
  reboot
}

function diagnose_self {
  wait_for_modem_usb_active
  if [ -z "${MODEM_USB_MODE}" ]; then
    return
  fi

  if [ "${MODEM_USB_MODE}" == "ACM" ]; then
    look_for_serial_port
    try_to_change_usb_data_conn # may reboot
  fi
}

# LTE/3G USB Ethernet
function activate_lte {
  if [ -z "${MODEM_USB_MODE}" ]; then
    return
  fi

  logger -s "Activating LTE/3G Module..."
  USB_ID=`dmesg | grep "New USB device found, idVendor=1ecb, idProduct=0208" | sed 's/^.*\] //g' | cut -f 1 -d ':' | cut -f 2 -d ' ' | tail -1`
  # when renamed
  IF_NAME=`dmesg | grep "renamed network interface usb1" | sed 's/^.* usb1 to //g' | cut -f 1 -d ' ' | tail -1`
  if [ -z "${IF_NAME}" ]; then
    IF_NAME=`dmesg | grep " ${USB_ID}" | grep "register 'cdc_ether'" | cut -f 2 -d ':' | cut -f 2 -d ' ' | tail -1`
  fi
  if [ -n "${IF_NAME}" ]; then
    ifconfig ${IF_NAME} up
    logger -s "The interface [${IF_NAME}] is up!"
    # Registering a new id
    modprobe usbserial vendor=0x1ecb product=0x0208
    RET=$?
    if [ "${RET}" != "0" ]; then
      if [ -e "/sys/bus/usb-serial/drivers/pl2303" ]; then
        echo "1ecb 0208" > /sys/bus/usb-serial/drivers/pl2303/new_id
      fi
    fi
    look_for_serial_port

  else
    IF_NAME=""
  fi
}

# start banner
logger -s "Initializing ${PRODUCT}..."

/opt/candy-line/ltepi2/bin/modem_on > /dev/null 2>&1
diagnose_self
activate_lte

# end banner
if [ "${MODEM_USB_MODE}" == "ECM" ]; then
  logger -s "${PRODUCT} is initialized successfully!"
  /usr/bin/env python /opt/candy-line/ltepi2/server_main.py ${MODEM_SERIAL_PORT} ${IF_NAME}
else
  logger -s "${PRODUCT} is not initialized... Silently terminated"
fi
