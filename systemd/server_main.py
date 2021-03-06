# -*- coding: utf-8 -*-

import fcntl
import json
import os
import signal
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
# sys.argv[1] ... The path to socket file,
#                 e.g. /var/run/candy-board-service.sock
# sys.argv[2] ... The network interface name to be monitored

LED = 'gpio%s' % os.environ['LED2']
logger = logging.getLogger('ltepi2')
logger.setLevel(logging.INFO)
handler = logging.handlers.SysLogHandler(address='/dev/log')
logger.addHandler(handler)
formatter = logging.Formatter('%(module)s.%(funcName)s: %(message)s')
handler.setFormatter(formatter)
led = 0
led_sec = float(os.environ['BLINKY_INTERVAL_SEC']) \
    if 'BLINKY_INTERVAL_SEC' in os.environ else 1.0
if led_sec < 0 or led_sec > 60:
    led_sec = 1.0
lte_ping_interval_sec = float(os.environ['LTE_PING_INTERVAL_SEC']) \
    if 'LTE_PING_INTERVAL_SEC' in os.environ else 0.0
router_enabled = (int(os.environ['ROUTER_ENABLED']) == 1) \
    if 'ROUTER_ENABLED' in os.environ else True
online = False
shutdown_state_file = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                   '__shutdown')


class Pinger(threading.Thread):
    DEST_ADDR = '<broadcast>'
    DEST_PORT = 60100
    CAT_PPP0_TX_STAT = 'cat /sys/class/net/ppp0/statistics/tx_bytes'

    def __init__(self, interval_sec):
        super(Pinger, self).__init__()
        if router_enabled:
            self.interval_sec = 0
        else:
            self.interval_sec = interval_sec
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(('', 0))
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.last_tx_bytes = 0

    def run(self):
        while self.interval_sec >= 5:
            if not os.path.isfile(Pinger.CAT_PPP0_TX_STAT):
                time.sleep(self.interval_sec)
                continue
            try:
                self.tx_bytes = subprocess.Popen(Pinger.CAT_PPP0_TX_STAT,
                                                 shell=True,
                                                 stdout=subprocess.PIPE
                                                 ).stdout.read()
                if int(self.tx_bytes) != self.last_tx_bytes:
                    self.socket.sendto('',
                                       (Pinger.DEST_ADDR, Pinger.DEST_PORT))
                    time.sleep(self.interval_sec)
                    self.last_tx_bytes = int(self.tx_bytes)
            except Exception:
                time.sleep(self.interval_sec)
                pass


class Monitor(threading.Thread):
    FNULL = open(os.devnull, 'w')

    def __init__(self, nic):
        super(Monitor, self).__init__()
        self.nic = nic

    def terminate(self):
        if os.path.isfile(shutdown_state_file):
            return False
        logger.error("LTEPi-II modem is terminated. Shutting down.")
        # exit from non-main thread
        os.kill(os.getpid(), signal.SIGTERM)
        return True

    def run(self):
        global online
        while True:
            try:
                if router_enabled:
                    err = subprocess.call("ip route | grep %s" % self.nic,
                                          shell=True,
                                          stdout=Monitor.FNULL,
                                          stderr=subprocess.STDOUT)
                    if err != 0 and not self.terminate():
                        continue

                err = subprocess.call("candy network show | grep ONLINE",
                                      shell=True,
                                      stdout=Monitor.FNULL,
                                      stderr=subprocess.STDOUT)
                online = (err == 0)
                if not online:
                    continue

                err = subprocess.call("ip route | grep default | grep -v %s" %
                                      self.nic, shell=True,
                                      stdout=Monitor.FNULL,
                                      stderr=subprocess.STDOUT)
                if err == 0:
                    ls_nic_cmd = ("ip route | grep default | grep -v %s " +
                                  "| tr -s ' ' | cut -d ' ' -f 5") % self.nic
                    ls_nic = subprocess.Popen(ls_nic_cmd,
                                              shell=True,
                                              stdout=subprocess.PIPE
                                              ).stdout.read()
                    logger.debug("ls_nic => [%s]" % ls_nic)
                    for nic in ls_nic.split("\n"):
                        if nic:
                            ip_cmd = ("ip route | grep %s " +
                                      "| awk '/default/ { print $3 }'") % nic
                            ip = subprocess.Popen(ip_cmd, shell=True,
                                                  stdout=subprocess.PIPE
                                                  ).stdout.read()
                            subprocess.call("ip route del default via %s" % ip,
                                            shell=True)
                else:
                    ip_cmd = ("ip route | grep %s "
                              "| awk '{ print $9 }'"
                              ) % self.nic
                    ip = subprocess.Popen(ip_cmd, shell=True,
                                          stdout=subprocess.PIPE
                                          ).stdout.read()
                    subprocess.call(
                        "ip route add default via %s" % ip,
                        shell=True,
                        stdout=Monitor.FNULL,
                        stderr=subprocess.STDOUT)
                time.sleep(5)

            except Exception:
                logger.error("Error on monitoring")
                if not self.terminate():
                    continue


def delete_sock_path(sock_path):
    # remove sock_path
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
    if 'PRESERVE_APN' not in os.environ or os.environ['PRESERVE_APN'] != '1':
        os.remove(apn_json)
    else:
        logger.info('Preserving the APN file[%s]' % apn_json)
    return apn


def modem_init_acm(serial_port, sock_path):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    serial = candy_board_amt.SerialPort(serial_port, 115200)
    server = candy_board_amt.SockServer(resolve_version(),
                                        resolve_boot_apn(),
                                        sock_path, serial)
    ret = server.perform({'category': 'modem', 'action': 'enable_acm'})
    logger.debug("modem_init_ecm() : modem, enable_acm => %s" % ret)
    sys.exit(json.loads(ret)['status'] != 'OK')


def modem_init_ecm(serial_port, sock_path):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    serial = candy_board_amt.SerialPort(serial_port, 115200)
    server = candy_board_amt.SockServer(resolve_version(),
                                        resolve_boot_apn(),
                                        sock_path, serial)
    ret = server.perform({'category': 'modem', 'action': 'enable_ecm'})
    logger.debug("modem_init_ecm() : modem, enable_ecm => %s" % ret)
    sys.exit(json.loads(ret)['status'] != 'OK')


def modem_init_autoconn(serial_port, sock_path):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    serial = candy_board_amt.SerialPort(serial_port, 115200)
    server = candy_board_amt.SockServer(resolve_version(),
                                        resolve_boot_apn(),
                                        sock_path, serial)
    ret = server.perform({'category': 'modem',
                          'action': 'enable_auto_connect'})
    logger.debug("modem_init_autoconn() : modem, enable_auto_connect => %s" %
                 ret)
    ret = json.loads(ret)
    if ret['status'] == 'OK':
        if ret['result'] == 'Already Enabled':
            sys.exit(0)
        else:
            sys.exit(1)
    sys.exit(2)


def blinky():
    global led, led_sec, online
    if not online:
        led = 1
    led = 0 if led != 0 else 1
    if led == 0 or router_enabled:
        subprocess.call("echo %d > /sys/class/gpio/%s/value" % (led, LED),
                        shell=True, stdout=Monitor.FNULL,
                        stderr=subprocess.STDOUT)
        threading.Timer(led_sec, blinky, ()).start()
    else:
        subprocess.call("echo %d > /sys/class/gpio/%s/value" % (1, LED),
                        shell=True, stdout=Monitor.FNULL,
                        stderr=subprocess.STDOUT)
        time.sleep(led_sec / 3)
        subprocess.call("echo %d > /sys/class/gpio/%s/value" % (0, LED),
                        shell=True, stdout=Monitor.FNULL,
                        stderr=subprocess.STDOUT)
        time.sleep(led_sec / 3)
        subprocess.call("echo %d > /sys/class/gpio/%s/value" % (1, LED),
                        shell=True, stdout=Monitor.FNULL,
                        stderr=subprocess.STDOUT)
        threading.Timer(led_sec / 3, blinky, ()).start()


def server_main(serial_port, nic,
                sock_path='/var/run/candy-board-service.sock'):
    delete_sock_path(sock_path)
    atexit.register(delete_sock_path, sock_path)

    logger.debug("server_main() : Setting up SerialPort...")
    serial = candy_board_amt.SerialPort(serial_port, 115200)
    logger.debug("server_main() : Setting up SockServer...")
    server = candy_board_amt.SockServer(resolve_version(),
                                        resolve_boot_apn(),
                                        sock_path, serial)
    if 'DEBUG' in os.environ and os.environ['DEBUG'] == "1":
        server.debug = True

    if 'BLINKY' in os.environ and os.environ['BLINKY'] == "1":
        logger.debug("server_main() : Starting blinky timer...")
        blinky()
    logger.debug("server_main() : Setting up Monitor...")
    monitor = Monitor(nic)
    logger.debug("server_main() : Setting up Pinger...")
    pinger = Pinger(lte_ping_interval_sec)

    logger.debug("server_main() : Starting SockServer...")
    server.start()
    logger.debug("server_main() : Starting Monitor...")
    monitor.start()
    logger.debug("server_main() : Starting Pinger...")
    pinger.start()

    logger.debug("server_main() : Joining Monitor thread into main...")
    monitor.join()
    logger.debug("server_main() : Joining Pinger thread into main...")
    pinger.join()
    logger.debug("server_main() : Joining SockServer thread into main...")
    server.join()


if __name__ == '__main__':
    if len(sys.argv) < 3:
        logger.error("USB Ethernet Network Interface isn't ready. " +
                     "Shutting down.")
    elif len(sys.argv) > 3:
        if sys.argv[3] == 'init_acm':
            modem_init_acm(sys.argv[1], sys.argv[2])
        elif sys.argv[3] == 'init_ecm':
            modem_init_ecm(sys.argv[1], sys.argv[2])
        elif sys.argv[3] == 'init_autoconn':
            modem_init_autoconn(sys.argv[1], sys.argv[2])
        else:
            logger.error("Do nothing: sys.argv[3]=%s" % sys.argv[3])
    else:
        logger.info("serial_port:%s, nic:%s" % (sys.argv[1], sys.argv[2]))
        try:
            server_main(sys.argv[1], sys.argv[2])
        except KeyboardInterrupt:
            pass
