#!/usr/bin/env bash

PRODUCT="LTEPi-II Board"
MODULE_SUPPORTED=0

function wait_for_modem_usb_inactive {
  MAX=30
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

function diagnose_self {
  RET=`dmesg | grep "register 'cdc_ether'"`
  RET=$?
  if [ "${RET}" != "0" ]; then
    return
  fi

  RET=`lsusb | grep 1ecb:0208`
  RET=$?
  if [ "${RET}" == "0" ]; then
    MODULE_SUPPORTED=1
  fi
}

# LTE/3G USB Ethernet
function inactivate_lte {
  if [ "${MODULE_SUPPORTED}" != "1" ]; then
    return
  fi

  logger -t ltepi2 "Inactivating LTE/3G Module..."
  USB_ID=`dmesg | grep "New USB device found, idVendor=1ecb, idProduct=0208" | sed 's/^.*\] //g' | cut -f 1 -d ':' | cut -f 2 -d ' ' | tail -1`
  IF_NAME=`dmesg | grep " ${USB_ID}" | grep "register 'cdc_ether'" | cut -f 2 -d ':' | cut -f 2 -d ' ' | tail -1`
  if [ -z "${IF_NAME}" ]; then
    # When renamed
    IF_NAME=`dmesg | grep "renamed network interface usb1" | sed 's/^.* usb1 to //g' | cut -f 1 -d ' ' | tail -1`
  fi
  if [ -n "${IF_NAME}" ]; then
    ifconfig ${IF_NAME} down
    logger -t ltepi2 "The interface [${IF_NAME}] is down!"

    RET=`ifconfig | grep wlan0`
    RET=$?
    if [ "${RET}" == "0" ]; then
      ifconfig "wlan0" down
      ifconfig "wlan0" up
    fi
  fi
}

# start banner
logger -t ltepi2 "Inactivating ${PRODUCT}..."

diagnose_self
inactivate_lte
/opt/candy-line/ltepi2/_modem_off.sh > /dev/null 2>&1
wait_for_modem_usb_inactive

# end banner
logger -t ltepi2 "${PRODUCT} is inactivated successfully!"
