# README for tools

tools には、Kompira Enterprise のための各種ツールが置かれています。

## tools/convert_files.py

Ver.1.5系、および、Ver.1.6.3 以前の Kompira Enterprise 上で作成された添付ファイルデータを、
Ver.1.6.4以降の Kompira に移行するためのツールです。


### 添付ファイル移行手順

#### (1) 事前準備

旧バージョンがインストールされた Kompira のサーバからオブジェクトをエクスポートして、新 Kompira サーバに
インポートしておきます。
(この時、添付ファイルは移行されないため、添付ファイルフィールドの添付ファイルデータは空となります)

#### (2) 添付ファイルの移行

tools/convert_files.py スクリプトを、旧バージョンの Kompira がインストールされているサーバの適当な
ディレクトリ上にコピーします。

次に旧 Kompira サーバ上で、移行先の Kompira のバージョンに合わせたオプションを指定して、上記の
convert_files.py コマンドを実行します。

なお、旧バージョンの Kompira が Ver.1.6.2 以降の場合、このコマンドの実行には root 権限が必要となり、
パスワード入力が求められます。sudo 権限を持つユーザか root ユーザで実行してください。

##### [移行先の Kompira のバージョンが Ver.1.6.7 以降の場合]

この場合は、オプション無しで以下のように実行します。
同じディレクトリに抽出した添付ファイルを含んだエクスポートデータが kompira_export_files.zip という
ZIP形式のファイルで作成されます。

    $ ./convert_files.py

##### [移行先の Kompira のバージョンが  Ver.1.6.4 - 1.6.6 の場合]

1.6.6 以前のバージョンでは、ZIP形式のエクスポートデータのインポートには対応していないため、従来の
JSON 形式で添付ファイルデータを取り出します。以下のように --json-mode オプションを付けて実行してください。

    $ ./convert_files.py --json-mode

上記を実行すると、kompira_export_files.json というファイルが作成されます。

#### (3) エクスポートデータのインポート

(2) で出力されたファイルを新バージョンがインストールされている Kompira サーバに転送してから、
新 Kompira 上で以下のように上書きインポートします。

    $ sudo /opt/kompira/bin/manage.py import_data --overwrite-mode kompira_export_files.zip  # または、kompira_export_files.json

ブラウザ上から添付ファイルをインポートする場合は、Kompiraサーバにブラウザからログインして、
'/' ディレクトリに移動してから、kompira_export_files.zip (または、kompira_export_files.json) を
上書きインポートしてください。

最後に、ブラウザからアクセスして、添付ファイルデータが移行されていることを確認してください。


### オプション

convert_files.py のオプションは以下のとおりです。

  --json-mode            JSON形式でファイルを出力します。

  --directory <PATH>     Kompira上の PATH 以下のオブジェクトに含まれる添付ファイルのみ抽出します。

  --filename <FILENAME>  出力するファイル名を指定します。