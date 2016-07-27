ltepi2-service
===

[![GitHub release](https://img.shields.io/github/release/CANDY-LINE/ltepi2-service.svg)](https://github.com/CANDY-LINE/ltepi2-service/releases/latest)
[![License BSD3](https://img.shields.io/github/license/CANDY-LINE/ltepi2-service.svg)](http://opensource.org/licenses/BSD-3-Clause)

ltepi2-serviceは、Raspberry Pi上で動作する[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)を動作させるためのシステムサービス（Raspberry Pi上で自動的に動作するソフトウェア）です。

本サービスでは、以下の機能を提供しています。

- AM Telecom社製LTE/3Gモジュールの自動初期設定(モデム設定とAPN設定)
- AM Telecom社製LTE/3Gモジュールの自動起動
- AM Telecom社製LTE/3Gモジュールを操作するコマンドラインツール
    - APN設定、表示
    - LTE/3Gネットワーク状態表示
    - SIM状態表示
    - モデム情報表示

また、以下のモジュールも同時にインストールされます。**常にインストールされます。**
- [candy-board-cli](https://github.com/CANDY-LINE/candy-board-cli) ... コマンドラインツール
- [candy-board-amt](https://github.com/CANDY-LINE/candy-board-amt) ... CANDY-LINE基板AM Telecomモデム向け共通モジュール

以下のモジュールは、インストールの可否を選択可能です。 **通常はインストールされます。**
- [CANDY RED](https://github.com/dbaba/candy-red) ... CANDY EGGクラウドサービスに接続可能なNode-REDベースのフローエディターです。Node.js v0.12またはv4.4が入っていない場合は、Node.js v0.12もインストールされます。すべてのインストールを終えるまでは、有線LAN環境で1~2時間以上かかる場合があります。

# 目次

1. [LTEPi for Dって何？](#ltepi-for-dって何)
1. [対応ハードウェア](#対応ハードウェア)
1. [対応OS](#対応OS)
1. [準備するもの](#準備するもの)
1. [バージョンアップ方法](#バージョンアップ方法)
1. [インストール方法](#インストール方法)
1. [アンインストール方法](#アンインストール方法)
1. [設定](#設定)
1. [LTEPi for D基板のGPIOピンマッピング](#ltepi-for-d基板のgpioピンマッピング)


# [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)って何？
Raspberry Pi B+やRaspberry Pi 2 Model Bに取り付けが可能なLTE通信モジュールを搭載した基板です。NTT DOCOMO及びNTT DOCOMOの回線を利用するMVNOのSIMを利用することができます。

Raspberry Pi 3にも取り付けることは可能ですが、条件に見合ったACアダプターが必要となります。また、ACアダプターのためのジャックも取り付けていただく必要があります。というのも電源の接続を誤りますとRaspberry Piや基板を壊してしまいますので、出荷時の状態ではRaspberry Pi 3に接続できないように設計されています。

# 対応ハードウェア
1. Raspberry Pi B+
1. Raspberry Pi2 Model B
1. ＜下記条件付対応＞ Raspberry Pi3
    * Raspberry Pi3につきましては消費電力が高いため、**5V/24WレベルのACアダプターと、ご利用者によるACジャックの半田付けが必要** となります
    * [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)の基板上にACジャックを取り付けてACアダプターから電力を供給した場合、**Raspberry Pi3へも電力が供給** されます。また、その場合 **Raspberry Pi3にある給電用USBを利用しない** ようにご注意ください。[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)やRaspberry Pi3が故障します

# 対応OS
Raspbian 4.4以降

# 準備するもの
インストールを行う前に以下のものを揃えておきましょう。

1. Raspberry Pi本体
1. Raspbianインストール済みのマイクロSDカード
1. [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)本体（あらかじめRaspberry Piに取り付けておいて下さい）
1. [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)付属のアンテナケーブルとアンテナ本体
1. SIMカード（回線契約が有効であるもの）
1. [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)付属のUSBケーブル
1. Raspberry Pi電源供給用USBケーブル
1. LANケーブル
1. インターネット・ブロードバンドルーター

# バージョンアップ方法
[インストール方法](#インストール方法)と同様です。インストール時に自動的にアンインストールが実行されます。

# インストール方法
最初にLANケーブルの一方をRaspberry Piに、もう一方をブロードバンドルーターに接続してインターネットに通信できる状態にしてください。電源はこの時点ではまだ入れないでください。

すでにRaspberry PiにてWi-Fiの設定を行い利用できている場合は、Wi-Fi経由で作業を行うことも可能です。

次に、[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)をRaspberry Piに設置します。また、付属のアンテナを2本ともモジュールに接続します。続けて、SIMカードを差し込みます。SIMカードは、金属面を下向きにして取り付けます。

最後に、付属のUSBケーブルで[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)とRaspberry Piを接続します。

これで準備が整いました。それでは、Raspberry Piの電源用USBケーブルを接続してRaspberry Piを起動させましょう。

Raspberry Piが起動したら、試しに以下のようなcURLコマンドを実行してみましょう。

```bash
$ curl -i -L --head http://www.candy-line.io/
```

下記のように`HTTP/1.1 200 OK`と出ていれば問題ありません。
```bash
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 23 Jul 2016 03:26:46 GMT
Content-Type: text/html
Content-Length: 16236
Connection: keep-alive
X-Accel-Version: 0.01
Last-Modified: Wed, 11 May 2016 01:37:07 GMT
ETag: "3f6c-532871464597b"
Accept-Ranges: bytes
Vary: Accept-Encoding
```

それでは、GitHub上にあるスクリプトをダウンロードしてインストールします。

以下のコマンドを実行します（`git.io`もGitHubの管理するドメインの1つです）。

```bash
$ curl -L https://git.io/vKyOf | sudo bash
```

[CANDY RED](https://github.com/dbaba/candy-red)を **インストールしない場合** は、以下のように`CANDY_RED=0`を指定します。
```bash
$ curl -L https://git.io/vKyOf | sudo CANDY_RED=0 bash
```

また、特定のバージョンを利用する場合は、以下のようにバージョンを指定することができます。
```bash
$ VERSION=1.2.3 && \
  curl -L https://raw.githubusercontent.com/CANDY-LINE/ltepi2-service/${VERSION}/install.sh | \
  sudo bash
```

実行すると以下のように表示されます。

    [INFO] Installing command lines to /opt/candy-line/ltepi2/bin...
              :
              :
    [INFO] Installing CANDY RED...
              :
              :
    [INFO] ltepi2 service has been installed
    [ALERT] *** Please reboot the system (enter 'sudo reboot') ***

なおインストールには時間がかかります。状況によっては1~2時間以上かかりますので、処理が止まっているように見えても途中で中断をしないようにしてください。

## インストール後の作業
インストールした後は、以下のコマンドを実行して再起動させましょう。

```bash
$ sudo reboot
```

再起動後しばらくすると、[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)のLEDにある2つのLEDのうち1つがオレンジ色で常時点灯となり、もう一つが点滅します。これはLTEモジュールが起動していることを表しています。

もし圏外だったり、アンテナが接続されていなかったりした場合は、LTEモジュールは起動できません。LEDの表示はオレンジ色の1つのみ点灯します。
以下にLTEモジュールが起動しない場合のトラブルシューティングをまとめていますので、ご確認ください。

### APN設定（コマンドライン）

既定の設定では、U-mobileの設定が反映されます。このため、お使いのSIMカードがU-mobile以外のものである場合は、以下の方法で変更する必要があります。

```bash
$ sudo candy apn set -n APN名 -u APNユーザーID -p APNパスワード
```

実行後、登録されているかどうかを以下のコマンドで確認することができます。
```bash
$ sudo candy apn ls
{
  "apns": [
    {
      "apn": "APN名",
      "user": "APNユーザーID",
      "apn_id": "1"
    }
  ]
}
```

なお、パスワードは表示されません。

設定変更を確認したら、再起動を行ってください。再起動すると変更したAPNを利用できるようになります。

```bash
$ sudo reboot
```

APN設定方法には、他にファイルを使用した方法もあります。以下にファイルによる変更方法を記します。

### APN設定（ファイル）

コマンドによるAPN設定のほか、あらかじめJSONファイルにAPNを書いておき、それを読み込ませる方法によってAPN設定を変更することもできます。

まずは以下のようなJSONファイルを作成します。ファイル名は、`boot-apn.json`とし、`/opt/candy-line/ltepi2`ディレクトリーに保存します。
```
{"apn":"APN名","user":"APNユーザーID","password":"APNパスワード"}
```
[こちら](systemd/boot-apn.json)に実際のファイルがあります。

ファイルを作成後、再起動を行ってください。再起動すると変更したAPNを利用できるようになります。ただし、再起動後は`boot-apn.json`が削除されます。これは、コマンドラインによるAPN設定変更が常に上書きされないようにするためです。

### LTEモジュールが起動しないときは？(LEDがオレンジだけ点灯しているとき)

LTEモジュールが動作するためにはいくつか条件が必要となります。Raspberry Piが動作するだけでは十分ではありませんので、うまくいかないときは以下の項目を確認して試してみてください。

1. ltepi2-serviceのインストールは完了していますか？ もしかすると、ltepi2-serviceをインストールしていない別のSDカードを使用しているかもしれません。ltepi2-serviceがインストールされていない場合、LTEモジュールは自動的に起動することはありません。`systemctl status ltepi2`を実施し、`(/lib/systemd/system/ltepi2.service; enabled)`と表示されていることを確認しましょう。
1. [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)とRaspberry Piは、付属のUSBケーブルで正しく接続されていますか？ Raspberry Pi本体の電源用USBアダプターとと[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)のUSB通信用アダプターは近い位置にありますから、間違えないようにしましょう。
1. NTT DOCOMOの電波の圏内ですか？ [こちら](https://www.nttdocomo.co.jp/support/area/)のサイトからFOMA/LTEのサービスエリアを確認し、サービスエリア圏内であることを確認しましょう。また、FOMA/LTE対応の携帯電話をお持ちであれば、FOMA/LTEの電波が圏内であることを確認してみましょう。
1. [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)にアンテナは正しく接続されていますか？ LTEモジュールは、電源が十分供給されていてもアンテナが接続されていないと起動することができません。LTEモジュールに接続するアンテナケーブルとアンテナ本体が、外れることなく取り付けられていることを確認しましょう。
1. Raspberry Piに供給する機器側からは十分な電力が供給できていますか？ [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)が動作するためには、Raspberry Piに加えてより多くの電力が必要になります。もしかするとUSBバスパワーを供給する機器側のUSBポートは、電力が十分ではないかもしれません。もしうまく動作しない場合は、別のUSBポートにつなぎ変えたり、別のUSB電源用意したりしてお試しください。
1. Raspberry Piに電源供給するために使用しているUSBケーブルは正しく動作していますか？ USBケーブルの商品の種類や使用状態によっては、[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)が動作するために必要な電力をRaspberry Piに伝えられていない可能性もあります。他のUSBケーブルもお試しください。

### ltepi2-serviceの起動と停止

ltepi2-serviceは、Raspberry Pi起動時に自動的に起動します。また、Raspberry Pi停止時には、自動的に停止します。一方で、手動で停止や起動を行うこともできます。

停止をする場合は、以下のようにコマンドを実行します。このコマンドを実行が完了するまでにはおよそ30秒かかります。これは、モデムの電源をOFFにした後OS上でUSBが無効になるタイミングを待っているためです。この時間は短縮させることができます。後述の「[サービス停止完了時間の短縮](#サービス停止完了時間の短縮)」をご覧ください。

```bash
$ sudo systemctl stop ltepi2
```

起動させるには、以下のコマンドを実行します。このコマンドの実行には1秒未満しかかかりませんが、実際にモデムが起動しOS上で準備ができるまで（LEDが点滅し始めるまで）には30〜40秒程度かかります。

```bash
$ sudo systemctl start ltepi2
```

上記の通り、停止には時間がかかるため、rebootコマンドなどで再起動を行う場合も同じように時間がかかります。

## CANDY REDへのブラウザー接続
オプション指定をせずインストールを行うと、[CANDY RED](https://github.com/dbaba/candy-red)が有効になっていますので、ブラウザーから接続してみましょう。Raspberry Piがつながっている有線または無線LANと同じネットワークにあるコンピューターのブラウザーで以下のアドレスを入力してページを表示させてみてください。
```
http://raspberrypi.local:8100
```
もしRaspberry Piのホスト名を変更していた場合は、「ホスト名.local」を「raspberrypi.local」の代わりに指定します。名前で繋がらないときは、IPアドレスを指定しましょう。

# アンインストール方法
ホームディレクトリーに移りアンインストールのスクリプトを実施してください。
```bash
$ cd ~
$ sudo /opt/candy-line/ltepi2/uninstall.sh
```
このコマンドでは、[CANDY RED](https://github.com/dbaba/candy-red)は削除されません。[CANDY RED](https://github.com/dbaba/candy-red)を削除する場合は、後述の「[CANDY REDのアンインストール](#candy-redのアンインストール)」をご覧ください。

実行すると以下のように表示されます。
```bash
$ cd ~
$ sudo /opt/candy-line/ltepi2/uninstall.sh
Removed symlink /etc/systemd/system/multi-user.target.wants/ltepi2.service.
[INFO] ltepi2 has been uninstalled
Uninstalling candy-board-amt:
  Successfully uninstalled candy-board-amt
Uninstalling candy-board-cli:
  Successfully uninstalled candy-board-cli
[ALERT] *** Please reboot the system! (enter 'reboot') ***
```

## CANDY REDのアンインストール
以下のコマンドを実行すると、[CANDY RED](https://github.com/dbaba/candy-red)を削除することができます。
```bash
$ sudo npm uninstall -g --unsafe-perm candy-red
```

# 設定

## LED点滅のON/OFF

既定の設定では、モデムが動作している間は[LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)のLEDが点滅します。また、その時間間隔は0.4秒となっています。

これらの設定は、インストール後に`/opt/candy-line/ltepi2/environment`にある以下の箇所に定義されています。

```
# 1 for enabling LED blinking, 0 for disabling it
BLINKY=1
# Blinking interval in seconds, > 0 and <= 60
BLINKY_INTERVAL_SEC=0.4
```

`BLINKY`を0にすると、点滅をなくすことができます。ただし、常時点灯させることはできません。

`BLINKY_INTERVAL_SEC`には、点滅の時間間隔を秒で指定します。小数点を使うことができます。0より大きく、60以下の値を設定します。

これらの設定を変更した場合は、Raspberry Piを再起動する必要があります。

## サービス停止完了時間の短縮

既定の設定では、サービスの停止までおよそ30秒かかります。これを8~10秒程度に短縮することができます。ただし、この設定を行うと、再度サービスを起動するときにうまく起動しないことがあります。具体的には、`systemctl restart ltepi2`のコマンドはうまく動作しなくなります。

サービス停止時間の短縮を行ってうまく起動しない場合は、一定時間（30~40秒程度）を置いてから再度実行するようにしましょう。

この設定は、インストール後に`/opt/candy-line/ltepi2/environment`にある以下の箇所に定義されています。
```
# 1 for enabling fast-shutdown ('systemctl restart' should always fail though)
FAST_SHUTDOWN=0
```
サービス停止完了時間を短縮させるには、上記の値を`0`から`1`に変更します。

この設定を変更した場合は、Raspberry Piを再起動する必要があります。

## CANDY EGG連携
ltepi2サービスをインストールすると、Raspberry Pi上にNode-REDベースのフローエディターである[CANDY RED](https://github.com/dbaba/candy-red)もインストールされます。通常のNode-REDとしての機能のほか、CANDY EGGクラウドサービスと連携して手軽にクラウドとのやりとりを行うアプリケーションを作成することができます。

初回インストール時に[CANDY RED](https://github.com/dbaba/candy-red)をインストールしていない場合(`CANDY_RED=0`を指定してインストールした場合)は、以下の手順で追加することができます。

### CANDY REDアプリケーションのインストール
まず最初に、ltepi2サービスを停止し、LANケーブルまたはWiFiでインターネットに接続します。これは、ダウンロードにかかる通信をLTEではなく有線・無線LANにて行うようにするためです。
```bash
$ sudo systemctl stop ltepi2
```
続いて、Node.jsを入れ替えます。Raspbian 4.1以降ではNode-REDがプリインストールされていますのでNode.jsもすでに入っています。しかし、[CANDY RED](https://github.com/dbaba/candy-red)インストール時に追加するアドオンを用意するときに、プリインストールされたNode.jsでは解決できないエラーが発生してしまいます。これを避けるため、Node.jsを入れ替えるようにします。

Raspberry Pi Model B+をお使いの場合は、以下のコマンドを実行します。
```bash
$ sudo apt-get update -y
$ sudo apt-get upgrade -y
$ wget http://node-arm.herokuapp.com/node_archive_armhf.deb
$ sudo dpkg -i node_archive_armhf.deb
$ sudo apt-get install -y python-dev python-rpi.gpio bluez
```

Raspberry Pi2をお使いの場合は、以下のコマンドを実行します。
```bash
$ sudo apt-get update
$ sudo apt-get upgrade
$ curl -sL https://deb.nodesource.com/setup_0.12 | sudo bash -
$ sudo apt-get install -y python-dev python-rpi.gpio bluez nodejs
```

続いて[CANDY RED](https://github.com/dbaba/candy-red)をインストールしましょう。インストールには、30分ほどかかります。
```bash
$ sudo NODE_OPTS=--max-old-space-size=128 npm install -g --unsafe-perm candy-red
```

### CANDY REDの動作確認
それでは動作しているかを確認します。
```bash
$ sudo systemctl status candy-red
```

上記を実行して、以下のような結果が得られれば問題ありません。

    ● candy-red.service - CANDY RED Gateway Service, version:
       Loaded: loaded (/lib/systemd/system/candy-red.service; enabled)
       Active: active (running) since Wed 2016-01-27 02:11:31 UTC; 594ms ago
     Main PID: 3612 (bash)
       CGroup: /system.slice/candy-red.service
               ├─3612 bash /usr/local/lib/node_modules/candy-red/services/start_systemd.sh
               └─3618 node --max-old-space-size=128 /usr/local/lib/node_modules/candy-red/dist/index.j...

    Jan 27 02:11:31 my-ltepi systemd[1]: Starting CANDY RED Gateway Service, version:...
    Jan 27 02:11:31 my-ltepi systemd[1]: Started CANDY RED Gateway Service, version:.
    Jan 27 02:11:31 my-ltepi start_systemd.sh[3612]: logger: Activating Bluetooth...
    Jan 27 02:11:31 my-ltepi start_systemd.sh[3612]: Can't get device info: No such device
    Jan 27 02:11:31 my-ltepi start_systemd.sh[3612]: logger: Starting candy-red...

なお、この時点で、端末を再起動したときには、自動的に[CANDY RED](https://github.com/dbaba/candy-red)が起動するようになります。

続いて、ltepiを再度起動しましょう。
```bash
$ sudo systemctl start ltepi2
```

1〜2分ほどで、モデムが起動しインターネットに接続します。以下のコマンドを実行して接続状況を確認することができます。

```bash
$ ip route | grep default
```

以下のように`usb0`と出ていれば成功です。
```
default via 192.168.225.1 dev usb0  metric 204
```

## CANDY REDへのブラウザー接続
最後にブラウザーから接続してみましょう。Raspberry Piがつながっている有線または無線LANと同じネットワークにあるコンピューターのブラウザーで以下のアドレスを入力してページを表示させてみてください。
```
http://raspberrypi.local:8100
```
もしRaspberry Piのホスト名を変更していた場合は、「ホスト名.local」を「raspberrypi.local」の代わりに指定します。名前で繋がらないときは、IPアドレスを指定しましょう。

## 対SDカード破損方法
ltepi2サービスや[CANDY RED](https://github.com/dbaba/candy-red)を動作させる場合は、通常スワップが発生することはありません。
しかし、Raspberry Piを使っていくうちに、気がつくとより多くのメモリーを使うプログラムを長期に渡って実行させてしまっていることもあるかもしれません。
そのような場合、Raspberry Piに装着されたSDカードは突然の電源断に対して脆弱となります。SDカードの破損は、SDカード書き込み中の電源断によって起こりやすいためです。

このため、Raspberry Piが販売された当初からいくつかの方法が紹介されているようです。例えば下記のようなものです。

 * http://www.e-ark.jp/raspberryjamsession-02/
 * http://raspberrypi.stackexchange.com/a/8038

また、上記のほか、Web検索にて種々の方法が紹介されていますので、目的や用途に合った方法をお試しください。
なお、これらの紹介はあくまで情報提供であり、私たちの保証する方法ではありませんのでご注意ください。

# [LTEPi for D](http://www.candy-line.io/test/proandsv.html#ltepiford)基板のGPIOピンマッピング

| RPi B+/2 GPIO  | AMP520/AMM570 |
| -------------- | ------------- |
|    20 (OUT)    |     POWER     |
|    21 (OUT)    |     RESET     |
|     6 (OUT)    |    RESERVED   |
|    14 (IN)     |      TX       |
|    15 (OUT)    |      RX       |
|    16 (IN)     |      RI       |

# 管理者向け
## モジュールリリース時の注意
1. [`install.sh`](install.sh)内の`VERSION=`にあるバージョンを修正してコミットする
1. 履歴を追記、修正してコミットする
1. （もし必要があれば）パッケージング
```bash
$ ./install.sh pack
```

## 開発用インストール動作確認
### パッケージング

```bash
$ ./install.sh pack
(scp to RPi then ssh)
```

`raspberrypi.local`でアクセスできる場合は以下のコマンドも利用可能。
```bash
$ make
(enter RPi password)
```

### 動作確認 (RPi)

```bash
$ VERSION=1.0.0 && rm -fr tmp && mkdir tmp && cd tmp && tar zxf ~/ltepi2-service-${VERSION}.tgz
$ time sudo SRC_DIR=$(pwd) DEBUG=1 ./install.sh
$ time sudo SRC_DIR=$(pwd) DEBUG=1 CANDY_RED=0 ./install.sh
```

# 履歴
* 1.0.2
    - AMP520の初期設定にかかる所要時間を短縮
* 1.0.1
    - AMP520において、自動接続モードがデフォルトで有効になるように修正
* 1.0.0
    - 初版
