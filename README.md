ltepi2-service
===

[![GitHub release](https://img.shields.io/github/release/CANDY-LINE/ltepi2-service.svg)](https://github.com/CANDY-LINE/ltepi2-service/releases/latest)
[![License BSD3](https://img.shields.io/github/license/CANDY-LINE/ltepi2-service.svg)](http://opensource.org/licenses/BSD-3-Clause)

ltepi2-serviceは、Raspberry Pi上で動作する[LTEPi for D](http://www.candy-line.io/proandsv.html#ltepiford)を動作させるためのシステムサービス（Raspberry Pi上で自動的に動作するソフトウェア）です。

ltepi2-serviceや、[LTEPi for D](http://www.candy-line.io/proandsv.html#ltepiford)に関する説明については、専用の[利用ガイド](https://github.com/CANDY-LINE/LTEPi2-info/blob/master/README.md)をご覧ください。

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

ホストを指定するときは、`PI_HOST`を指定する。
```bash
$ make PI_HOST=shinycandypi.local
(enter RPi password)
```

### 動作確認 (RPi)

```bash
$ VERSION=1.3.2 && rm -fr tmp && mkdir tmp && cd tmp && \
  tar zxf ~/ltepi2-service-${VERSION}.tgz
$ time sudo SRC_DIR=$(pwd) DEBUG=1 ./install.sh
$ time sudo SRC_DIR=$(pwd) DEBUG=1 CANDY_RED=0 ./install.sh
```

# 履歴
* 2.0.0
    - CANDY-REDをインストールする場合に、Node.js v4.xをインストールするように変更。Node-RED v0.16.0より Node.js v0.12がサポート外となったため。**すでにv0.12が入っている場合はアンインストールされて、入れ替えられます。ご注意ください**
    - `sudo systemctl stop ltepi2`を実行するとインターネットへ接続できなくなるので、ラズパイ本体の再起動を行うこと
* 1.3.2
    - FTDI USBモジュールをRaspberry Piに差し込んだまま起動すると、LTEモデムが正しく動作しない問題を修正
    - シャットダウン時にサービスが正常終了しない問題を修正
* 1.3.1
    - pipインストール時に不要となったオプションを削除
* 1.3.0
    - [candy-iot-service](https://github.com/CANDY-LINE/candy-iot-service) との互換性を取るための変更を反映
* 1.2.0
    - モデムによるインターネット接続時にのみLEDが点滅するように変更
* 1.1.1
    - pipのインストールを追加
* 1.1.0
    - CANDY REDのデフォルトフローを追加
* 1.0.5
    - CANDY REDをインストールする際のデフォルトフローを指定
* 1.0.4
    - `apt-get upgrade`を常に強制せず利用者のタイミングで実行できるように変更
* 1.0.3
    - CANDY REDに必要な依存関係を追加
* 1.0.2
    - AMP520の初期設定にかかる所要時間を短縮
* 1.0.1
    - AMP520において、自動接続モードがデフォルトで有効になるように修正
* 1.0.0
    - 初版
