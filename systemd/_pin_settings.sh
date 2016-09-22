#!/usr/bin/env bash

echo -e "\033[93m[WARN] *** INTERNAL USE, DO NOT RUN DIRECTLY *** \033[0m"


# Module Pins     RPi Pins
# ----------------------------------------------------
# POWER_KEY(6) => 20 (Output, Active high, 1+ sec for turning on/off module)
# RESET_N(67)  => 21 (Output, Active low, 1+ sec for module reset)
# RESEVED(8)   =>  6 (Output, Active low, WWAN disable function)
# TX(22)       => 14 (Input, Transmit Data to module)
# RX(24)       => 15 (Output, Receive Data from module)
# RI(38)       => 16 (Input, Ring Indicator)
POWER_KEY=20
POWER_KEY_PIN="/sys/class/gpio/gpio${POWER_KEY}"
POWER_KEY_DIR="${POWER_KEY_PIN}/direction"

RESET_N=21
RESET_N_PIN="/sys/class/gpio/gpio${RESET_N}"
RESET_N_DIR="${RESET_N_PIN}/direction"

WWAN_DISABLE=6
WWAN_DISABLE_PIN="/sys/class/gpio/gpio${WWAN_DISABLE}"
WWAN_DISABLE_DIR="${WWAN_DISABLE_PIN}/direction"

TXD=14
TXD_PIN="/sys/class/gpio/gpio${TXD}"
TXD_DIR="${TXD_PIN}/direction"

RXD=15
RXD_PIN="/sys/class/gpio/gpio${RXD}"
RXD_DIR="${RXD_PIN}/direction"

RI=16
RI_PIN="/sys/class/gpio/gpio${RI}"
RI_DIR="${RI_PIN}/direction"

LED2=4
LED2_PIN="/sys/class/gpio/gpio${LED2}"
LED2_DIR="${LED2_PIN}/direction"

function setup_ports {
  for p in ${POWER_KEY} ${RESET_N} ${WWAN_DISABLE} ${TXD} ${RXD} ${RI} ${LED2}; do
    [[ ! -f "/sys/class/gpio/gpio${p}/direction" ]] && echo  "${p}"  > /sys/class/gpio/export
  done
}

function setup_pin_directions {
  echo "out" > ${POWER_KEY_DIR}
  echo "out" > ${RESET_N_DIR}
  echo "out" > ${WWAN_DISABLE_DIR}
  echo "in"  > ${TXD_DIR}
  echo "out" > ${RXD_DIR}
  echo "in"  > ${RI_DIR}
  echo "out" > ${LED2_DIR}
}
