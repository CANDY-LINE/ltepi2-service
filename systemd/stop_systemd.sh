#!/usr/bin/env bash

PRODUCT="LTEPi-II Board"
MODULE_SUPPORTED=0

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

  logger -s "Inactivating LTE/3G Module..."
  USB_ID=`dmesg | grep "New USB device found, idVendor=1ecb, idProduct=0208" | sed 's/^.*\] //g' | cut -f 1 -d ':' | cut -f 2 -d ' ' | tail -1`
  IF_NAME=`dmesg | grep " ${USB_ID}" | grep "register 'cdc_ether'" | cut -f 2 -d ':' | cut -f 2 -d ' ' | tail -1`
  if [ -z "${IF_NAME}" ]; then
    # When renamed
    IF_NAME=`dmesg | grep "renamed network interface usb1" | sed 's/^.* usb1 to //g' | cut -f 1 -d ' ' | tail -1`
  fi
  if [ -n "${IF_NAME}" ]; then
    ifconfig ${IF_NAME} down
    logger -s "The interface [${IF_NAME}] is down!"

    RET=`ifconfig | grep wlan0`
    RET=$?
    if [ "${RET}" == "0" ]; then
      ifconfig "wlan0" down
      ifconfig "wlan0" up
    fi
  fi
}

# start banner
logger -s "Inactivating ${PRODUCT}..."

diagnose_self
inactivate_lte
/opt/candy-line/ltepi2/bin/modem_off > /dev/null 2>&1

# end banner
logger -s "${PRODUCT} is inactivated successfully!"
