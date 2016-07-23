# -*- coding: utf-8 -*-

import fcntl
import json
import os
import socket
import select
import struct
import sys
import termios
import threading
import time
import subprocess
import atexit
import re
import candy_board_amt
import logging
import logging.handlers

# sys.argv[0] ... Serial Port
# sys.argv[1] ... The path to socket file, e.g. /var/run/candy-board-service.sock
# sys.argv[2] ... The network interface name to be monitored

logger = logging.getLogger('ltepi2')
logger.setLevel(logging.INFO)
handler = logging.handlers.SysLogHandler(address = '/dev/log')
logger.addHandler(handler)
formatter = logging.Formatter('%(module)s.%(funcName)s: %(message)s')
handler.setFormatter(formatter)

class Monitor(threading.Thread):
    FNULL = open(os.devnull, 'w')

    def __init__(self, nic):
        super(Monitor, self).__init__()
        self.nic = nic

    def run(self):
        while True:
            err = subprocess.call("ip route | grep %s" % self.nic, shell=True, stdout=Monitor.FNULL, stderr=subprocess.STDOUT)
            if err != 0:
                logger.error("LTEPi-II modem is terminated. Shutting down.")
                sys.exit(1)
            err = subprocess.call("ip route | grep default | grep -v %s" % self.nic, shell=True, stdout=Monitor.FNULL, stderr=subprocess.STDOUT)
            if err == 0:
                ls_nic_cmd = "ip route | grep default | grep -v %s | tr -s ' ' | cut -d ' ' -f 5" % self.nic
                ls_nic = subprocess.Popen(ls_nic_cmd, shell=True, stdout=subprocess.PIPE).stdout.read()
                logger.debug("modem_init() : ls_nic => %s" % ls_nic)
                for nic in ls_nic.split("\n"):
                    if nic:
                        ip_cmd = "ip route | grep %s | awk '/default/ { print $3 }'" % nic
                        ip = subprocess.Popen(ip_cmd, shell=True, stdout=subprocess.PIPE).stdout.read()
                        subprocess.call("ip route del default via %s" % ip, shell=True)
            time.sleep(5)

def delete_sock_path(sock_path):
    try:
        os.unlink(sock_path)
    except OSError:
        if os.path.exists(sock_path):
            raise

def resolve_version():
    if 'VERSION' in os.environ:
        return os.environ['VERSION']
    return 'N/A'

def resolve_boot_apn():
    dir = os.path.dirname(os.path.abspath(__file__))
    apn_json = dir + '/boot-apn.json'
    if not os.path.isfile(apn_json):
        return None
    with open(apn_json) as apn_creds:
        apn = json.load(apn_creds)
    os.remove(apn_json)
    return apn

def modem_init(serial_port, sock_path):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    serial = candy_board_amt.SerialPort(serial_port, 115200)
    server = candy_board_amt.SockServer(resolve_version(), resolve_boot_apn(), sock_path, serial)
    ret = server.perform({'category':'modem', 'action':'enable_ecm'})
    logger.debug("modem_init() : modem, enable_ecm => %s" % ret)
    sys.exit(json.loads(ret)['status'] != 'OK')

def modem_reset(serial_port, sock_path):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    serial = candy_board_amt.SerialPort(serial_port, 115200)
    server = candy_board_amt.SockServer(resolve_version(), resolve_boot_apn(), sock_path, serial)
    ret = server.perform({'category':'modem', 'action':'enable_acm'})
    logger.debug("modem_init() : modem, enable_acm => %s" % ret)
    sys.exit(json.loads(ret)['status'] != 'OK')

def server_main(serial_port, nic, sock_path='/var/run/candy-board-service.sock'):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    logger.debug("server_main() : Setting up Monitor...")
    monitor = Monitor(nic)
    monitor.start()

    logger.debug("server_main() : Setting up SerialPort...")
    serial = candy_board_amt.SerialPort(serial_port, 115200)
    logger.debug("server_main() : Setting up SockServer...")
    server = candy_board_amt.SockServer(resolve_version(), resolve_boot_apn(), sock_path, serial)
    if 'DEBUG' in os.environ and os.environ['DEBUG'] == "1":
        server.debug = True

    logger.debug("server_main() : Starting SockServer...")
    server.start()
    logger.debug("server_main() : Joining Monitor thread into main...")
    monitor.join()
    logger.debug("server_main() : Joining SockServer thread into main...")
    server.join()

if __name__ == '__main__':
    if len(sys.argv) < 3:
        logger.error("USB Ethernet Network Interface isn't ready. Shutting down.")
    elif len(sys.argv) > 3:
        if sys.argv[3] == 'init':
            modem_init(sys.argv[1], sys.argv[2])
        else:
            modem_reset(sys.argv[1], sys.argv[2])
    else:
        logger.info("serial_port:%s, nic:%s" % (sys.argv[1], sys.argv[2]))
        server_main(sys.argv[1], sys.argv[2])
