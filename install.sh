#!/bin/bash
#
# Copyright (c) 2012- Fixpoint Inc. All rights reserved.
# ---
# Kompira簡易インストーラ：
#   - 1台構成版
#   - Apache/PostgreSQLを使用
#
# 動作要件：
#   - x86_64
#   - OS
#     - Red Hat Enterprise Linux (RHEL) 8.x 系
#     - Red Hat Enterprise Linux (RHEL) 7.x 系 (7.6 以上)
#     - Rocky Linux 8.x 系
#     - AlmaLinux OS 8.x 系
#     - MIRACLE LINUX 8.x 系
#     - Amazon Linux 2
#   - Python
#     - Python 3.9 (experimental)
#     - Python 3.8 (recommended)
#     - Python 3.7 (not recommended)
#     - Python 3.6 (deprecated)
#   - PostgreSQL
#     - PostgreSQL 12 .. 17 (RHEL8/Rocky/AlmaLinux/MIRACLE)
#     - PostgreSQL 12 .. 15 (RHEL7)
#     - PostgreSQL 12 .. 14 (AmazonLinux2)
#
shopt -s extglob
SETUP_TYPE="Install the Kompira"
INSTALL_LOG="install.$$.log"
THIS_DIR=$(dirname $(readlink -f $0))

. $THIS_DIR/scripts/setup_utils.sh

KOMPIRA_LOGIN=/bin/bash
KOMPIRA_PKGNAME_DEFAULT=Kompira
KOMPIRA_PKGNAME_JOBMNGR=Kompira-jobmngr
KOMPIRA_PKGNAME_SENDEVT=Kompira-sendevt
#
# Kompira パッケージファイル名（py3-none-any の部分はコンパイルした python のバージョンによって異なる）
#
: ${DIST_DIR:=$THIS_DIR/dist}
KOMPIRA_WHLFILE_DEFAULT="$DIST_DIR/Kompira-$VERSION-py3-none-any.whl"
KOMPIRA_WHLFILE_JOBMNGR="$DIST_DIR/Kompira_jobmngr-$VERSION-py3-none-any.whl"
KOMPIRA_WHLFILE_SENDEVT="$DIST_DIR/Kompira_sendevt-$VERSION-py3-none-any.whl"

KOMPIRA_TEST_URL="https://localhost/"
KOMPIRA_DB_TABLE_EXISTS=false
KOMPIRA_DB_USER_EXISTS=false
KOMPIRA_EXTRA_CONFIGS="kompira_audit.yaml"
#
# DB暗号化フィールド用共有秘密鍵
#
DB_SECRET_KEY_LEN=12        # 自動作成時のキー長
DB_SECRET_KEY_MIN_LEN=8     # kompira_site.parameters.KOMPIRA_SECRET_KEY_MIN_LEN に合わせる
DB_SECRET_KEY=
#
# HTTP(S) アクセス可能かチェックする URL
#
CHECK_ACCESSIBILITY="https://download.postgresql.org"

#
# 古いため無効にするレポジトリ情報
#
DEPRECATED_REPOS="pgdg95 pgdg96 "
DEPRECATED_REPOS+=$(set -- $(seq 10 $DEPRECATED_PGVER); echo "${@/#/pgdg}")

#
# オプションで有効化するリポジトリ
#
: ${OPTION_REPONAME:=""}

#
# postgresql バージョン移行時に必要なディスク空き容量％（対データ量）
#
: ${PG_MIGRATE_REQUIRE_FREERATE:=120}

#
# epel レポジトリ情報
#
EPEL_REPONAME="epel"
EPEL_REPOPKG="epel-release"
EPEL_YUMREPO="https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RHEL_VERSION}.noarch.rpm"
EPEL7_YUMREPO="https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm"

#
# localhost チェック用ワンライナー
#
PYTHON_CHECK_LOCALHOST='from socket import *; [socket(*res[:3]) and exit(0) for res in getaddrinfo("localhost", 0, 0, SOCK_STREAM)] or exit(1)'

#
# firewalld/iptables の許可ポート
#
FIREWALLD_ACCEPT_PORTS="http https 5671/tcp 5672/tcp"
IPTABLES_ACCEPT_PORTS="80/tcp 443/tcp 5671/tcp 5672/tcp"

#
# SELinux のモード
#
: ${SELINUX_MODE:="permissive"}

#
# 言語パックパッケージ
#
: ${LANGUAGES:="en ja"}
PACKAGES_FOR_LANGPACK=$(set -- $LANGUAGES; echo "${@/#/glibc-langpack-}")

#
# インストール自体に必要なパッケージ
#
PACKAGES_FOR_UPDATE="nss"
PACKAGES_FOR_INSTALL="yum-utils nss $PACKAGES_FOR_LANGPACK"
PACKAGES_FOR_BUILD="gcc make"
if [ "$SYSTEM_NAME" == "amzn2023" ]; then
    PACKAGES_FOR_INSTALL="$PACKAGES_FOR_INSTALL curl-minimal"
else
    PACKAGES_FOR_INSTALL="$PACKAGES_FOR_INSTALL curl"
fi

#
# kompira_sendevt に必要なパッケージ
#
PACKAGES_FOR_SENDEVT=""
PACKAGES_FOR_SENDEVT_BUILD=""

#
# kompira_jobmngr に必要なパッケージ
#
PACKAGES_FOR_JOBMNGR="krb5-workstation openssl libffi ca-certificates"
PACKAGES_FOR_JOBMNGR_BUILD="krb5-devel openssl-devel libffi-devel"

#
# kompira サーバに必要なパッケージ
#
PACKAGES_FOR_KOMPIRA="httpd mod_ssl mercurial git sudo iproute jq memcached postfix expect patch"
PACKAGES_FOR_KOMPIRA_BUILD="httpd-devel"

#
# 冗長構成セットアップ(setup_cluster.sh)に必要なパッケージ
#
PACKAGES_FOR_SETUP_CLUSTER="ipcalc"

#
# SELinux 関連のパッケージ
#
if [ $RHEL_VERSION == 7 ]; then
    PACKAGES_FOR_SELINUX="audit policycoreutils-python"
else
    PACKAGES_FOR_SELINUX="audit policycoreutils-python-utils"
fi

#
# インストールする Python のバージョン
#
: ${PYTHON_VERSION:=""}

#
# インストールする PostgreSQL のバージョン
#
: ${POSTGRESQL_SPEC_VERSION:=""}
: ${NEW_PG_MAJVER:=""}

#
# 追加でインストールするパッケージ
#
: ${WITH_RPM:=""}
: ${WITH_WHL:=""}

#
# extra パッケージ構築に必要なパッケージ
#
: ${PACKAGES_FOR_EXTRA:="createrepo rpm-build"}

#
# extra パッケージの modules 対応に必要なパッケージ
#
: ${PACKAGES_FOR_MODULES:=""}
if [ "$SYSTEM_NAME" == "amzn2023" ]; then
    # MEMO: AmazonLinux2023 では modulemd-tools が提供されていないため CentOS Stream 9 の RPM パッケージを流用する
    : ${MODULEMD_TOOLS_RPM:="https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/modulemd-tools-0.9-5.el9.noarch.rpm"}
    PACKAGES_FOR_MODULES="$PACKAGES_FOR_MODULES createrepo_c $MODULEMD_TOOLS_RPM"
elif [ $RHEL_VERSION -ge 8 ]; then
    PACKAGES_FOR_MODULES="$PACKAGES_FOR_MODULES createrepo_c modulemd-tools"
fi

#
# extra パッケージに追加で加えるパッケージ
#
: ${PACKAGES_FOR_OFFLINE:=""}
: ${REQUIREMENTS_FOR_OFFLINE:=""}

#
# gdb/debuginfo パッケージ
#
: ${PACKAGES_FOR_GDB:="gdb glibc"}
: ${DEBUGINFO:="glibc"}

#
# ロケールの設定
#
: ${CONFIG_LOCALE_LANG:=false}
: ${CONFIG_LOCALE_TIMEZONE:=false}
: ${LOCALE_LANG:=""}
: ${LOCALE_TIMEZONE:="Asia/Tokyo"}
: ${LOCALE_CLOCK_UTC:="false"}

#
# LOCALE_LANG のデフォルトは postgres の locale 設定があればそれを引き継ぐ
# なければ System Locale の設定を引き継ぐ
#
if [ -z "$LOCALE_LANG" ]; then
    PGSQL_LANG=$(psql -U $PGSQL_USER -d $PGSQL_DB -At -c "show lc_collate;" 2>/dev/null)
    if [ -n "$PGSQL_LANG" ]; then
        LOCALE_LANG=$PGSQL_LANG
    else
        SYSTEM_LOCALE=$(localectl|grep 'System Locale')
        LOCALE_LANG=${SYSTEM_LOCALE#*=}
    fi
fi

#
# インストール時の proxy の設定
#
: ${TEMP_PROXY_URL:="$PROXY_URL"}
: ${TEMP_NO_PROXY:="$NO_PROXY"}

HTTPS_MODE=true
AMQPS_MODE=true
AMQPS_VERIFY_MODE=false
AMQP_ALLOWED=false
FORCE_MODE=false
BACKUP_MODE=
BACKUP_PROCESS=
INITDATA_MODE=false
INITFILE_MODE=false
EXTRA_MODE=false
EXTRA_WITH_HA=true
JOBMNGR_MODE=false
SENDEVT_MODE=false
KOMPIRA_SERVER=localhost
REQUIRES_ONLY=false
WITH_GDB=false
INSTALL_ONLY=false
DRY_RUN=false
SKIP_PYTHON3_INSTALL=false
SKIP_CLUSTER_START=false
SKIP_SCP_CERTS=false
SKIP_RABBITMQ_UPDATE=false
SKIP_POSTGRESQL_UPDATE=false
CLUSTER_FULLSTOP_UPGRADE=false
CLUSTER_CONFIG_LOST=false
RABBITMQ_UPGRADED=false
RABBITMQ_WIPE_DATA=false
RABBITMQ_EXCLUDED_VERSIONS=""
RABBITMQ_AVAILABLE_VERSIONS=""
RABBITMQ_AVAILABLE_NEWER=false
RABBITMQ_SPEC_VERSION=""
RABBITMQ_LATEST_VERSION=""

SHOW_OPTIONS="$SHOW_OPTIONS LOCALE_LANG PATH HTTPS_MODE AMQPS_MODE FORCE_MODE BACKUP_MODE BACKUP_PROCESS INITDATA_MODE INITFILE_MODE OFFLINE_MODE JOBMNGR_MODE SENDEVT_MODE PROXY_URL NO_PROXY KOMPIRA_SERVER INSTALL_ONLY DRY_RUN"

init_variables_pgsql()
{
    #
    # インストールする postgresql のバージョンをチェックする
    #
    if [ "$POSTGRESQL_SPEC_VERSION" != "latest" ] && [ -n "$POSTGRESQL_SPEC_VERSION" ]; then
        # A          -> NEW_PG_MAJVER=A; POSTGRESQL_SPEC_VERSION="A.*"
        # A.B | A.*  -> NEW_PG_MAJVER=A
        if [[ "$POSTGRESQL_SPEC_VERSION" =~ ^[0-9]+$ ]]; then
            NEW_PG_MAJVER="$POSTGRESQL_SPEC_VERSION"
            POSTGRESQL_SPEC_VERSION+=".*"
        elif [[ "$POSTGRESQL_SPEC_VERSION" =~ ^[0-9]+\.(\*|[0-9]+)$ ]]; then
            NEW_PG_MAJVER="${POSTGRESQL_SPEC_VERSION%%.*}"
        else
            abort_setup "INVALID POSTGRESQL VERSION ($POSTGRESQL_SPEC_VERSION) SPECIFIED!"
        fi
    fi
    if [ -z "$NEW_PG_MAJVER" ]; then
        if [ "$POSTGRESQL_SPEC_VERSION" == "latest" ] || [ -z "$CUR_PG_MAJVER" ] || [ $CUR_PG_MAJVER -lt $SUPPORTED_PGVER_MIN ] || [ $CUR_PG_MAJVER -ge 60 ]; then
            # postgresql が動作していないので LATEST_PGVER を新規インストールする
            # または 古すぎる postgresql が動作しているので LATEST_PGVER にアップグレードする
            if [ "$SYSTEM" == "AMZN" ]; then
                if [ $SYSTEM_NAME == "amzn2023" ]; then
                    NEW_PG_MAJVER=$LATEST_PGVER_AMZN2023
                else
                    NEW_PG_MAJVER=$LATEST_PGVER_AMZN2
                fi
            elif [ $RHEL_VERSION == 7 ]; then
                NEW_PG_MAJVER=$LATEST_PGVER_RHEL7
            else
                NEW_PG_MAJVER=$LATEST_PGVER_DEFAULT
            fi
        else
            # 互換性のある postgresql であるのでこのまま保持する（勝手にアップグレードしない）
            NEW_PG_MAJVER=$CUR_PG_MAJVER
        fi
    fi
    if [ "$POSTGRESQL_SPEC_VERSION" == "latest" ]; then
        POSTGRESQL_SPEC_VERSION="${NEW_PG_MAJVER}.*"
    fi

    #
    # variables for postgres (system and version dependent)
    #
    if [ "$SYSTEM" == "AMZN" ]; then
        NEW_PG_SERVICE="postgresql"
        NEW_PG_DATADIR="/var/lib/pgsql/data"
        NEW_PG_SETUP="postgresql-setup"
        if [ $SYSTEM_NAME == "amzn2023" ]; then
            NEW_PG_PREFIX="postgresql${NEW_PG_MAJVER}"
        else
            NEW_PG_PREFIX="postgresql"
        fi
    else
        NEW_PG_SERVICE="postgresql-${NEW_PG_MAJVER}"
        NEW_PG_DATADIR="/var/lib/pgsql/${NEW_PG_MAJVER}/data"
        NEW_PG_SETUP="postgresql-${NEW_PG_MAJVER}-setup"
        NEW_PG_PREFIX="postgresql${NEW_PG_MAJVER}"
    fi
    NEW_PG_BASEDIR=$(dirname $NEW_PG_DATADIR)

    #
    # determine PostgreSQL migration
    #
    POSTGRESQL_MIGRATE=false
    POSTGRESQL_UPGRADE=false
    if [ -n "$CUR_PG_MAJVER" ]; then
        if [ $CUR_PG_MAJVER -ge 60 ]; then
            INITDATA_MODE=true
            BACKUP_MODE=false
            BACKUP_PROCESS=false
        elif [ $CUR_PG_MAJVER -lt $NEW_PG_MAJVER ]; then
            POSTGRESQL_MIGRATE=true
            POSTGRESQL_UPGRADE=true
        elif [ $CUR_PG_MAJVER -gt $NEW_PG_MAJVER ]; then
            POSTGRESQL_MIGRATE=true
        fi
    fi

    # TODO: Amazon Linux 環境での PostgreSQL アップグレード対応
    if $POSTGRESQL_MIGRATE && [ "$SYSTEM" == "AMZN" ]; then
        abort_setup "Sorry, PostgreSQL upgrade is not supported on Amazon Linux."
    fi
}

init_variables()
{
    init_variables_pgsql
}

check_localhost()
{
    $PLATFORM_PYTHON -c "$PYTHON_CHECK_LOCALHOST" > /dev/null 2>&1
}

check_environ()
{
    echo_title "Check current environment."
    # LANG が C/C.UTF-8 の場合は --locale-lang の指定を促してエラーとする。
    local lang=(${LOCALE_LANG/./ })
    local country=${lang[0]}
    if [ "$country" == "C" ]; then
        abort_setup "The current LOCALE_LANG ($LOCALE_LANG) does not specify the language." \
                    "Please specify LANG with --locale-lang option."
    fi
    if [ -n "$TEMP_PROXY_URL" ]; then
        # インストール時のプロキシ環境変数を設定する
        echo_debug "settings http_proxy for install: $TEMP_PROXY_URL"
        echo_debug "settings no_proxy for install: $TEMP_NO_PROXY"
        export http_proxy="$TEMP_PROXY_URL"
        export https_proxy="$TEMP_PROXY_URL"
        export HTTP_PROXY="$TEMP_PROXY_URL"
        export HTTPS_PROXY="$TEMP_PROXY_URL"
        export no_proxy="$TEMP_NO_PROXY"
    fi
    check_arch
    check_system
    check_subscription $OFFLINE_MODE

    # Azure 環境では Microsoft リポジトリをアップデートしておく
    # TODO: プラットフォーム判定処理を整理する
    local AZURE_SMBIOS_ASSET_TAG="7783-7084-3265-9085-8269-3286-77"
    local CHASSIS_ASSET_TAG
    if which dmidecode >/dev/null 2>&1; then
        CHASSIS_ASSET_TAG="$(dmidecode --string chassis-asset-tag)"
    fi
    echo_info "CHASSIS_ASSET_TAG=$CHASSIS_ASSET_TAG"
    if [ "$CHASSIS_ASSET_TAG" == "$AZURE_SMBIOS_ASSET_TAG" ]; then
        echo_info "Microsoft Azure environment detected, update Microsoft repository."
        verbose_run yum update -y --disablerepo='*' --enablerepo='*microsoft*'
    fi

    if $EXTRA_MODE; then
        # extra パッケージを作成する前に、既存 extra パッケージのモジュールを事前に無効化する
        disable_kompira_extra_module
        # GPG KEY を更新する
        update_rpm_gpg_key
        return 0
    elif ! $OFFLINE_MODE; then
        # オンラインインストールする前に、既存 extra パッケージのモジュールを事前に無効化する
        disable_kompira_extra_module
        # ネットワークアクセスできるか確認する
        echo_info "Check network accessibility"
        local index=0
        for url in $CHECK_ACCESSIBILITY; do
            let index=$index+1
            verbose_run curl -x "$TEMP_PROXY_URL" --connect-timeout 10 -kvfI "$url" > /dev/null 2> $TMPDIR/test-accessibility$index.out
            if [ $? != 0 ]; then
                cat $TMPDIR/test-accessibility$index.out
                echo_error "[ERROR] Can not connect to $url"
                echo_error "Please make sure this server can connect to the internet. Or check the proxy settings."
                abort_setup
            fi
            echo_info "OK: $url"
        done
        # GPG KEY を更新する
        update_rpm_gpg_key
    else
        # オフラインインストールに必要な extra パッケージが展開されているかチェック
        local dir
        if [ ! -f $KOMPIRA_EXTRA_REPO ]; then
            abort_setup "$KOMPIRA_EXTRA_REPO not found!"
        fi
        for dir in $KOMPIRA_EXTRA_PIP $KOMPIRA_EXTRA_RPM; do
            if [ ! -d $dir ]; then
                abort_setup "$dir not found!"
            fi
        done
        # オフラインインストールのために extra パッケージのモジュールを有効化する
        enable_kompira_extra_module
    fi
    if ! $JOBMNGR_MODE && ! $SENDEVT_MODE; then
        # 旧バージョンの PostgreSQL チェック (Amazon 以外)
        if [ "$SYSTEM" != "AMZN" ] && rpm -q postgresql > /dev/null 2>&1; then
            abort_setup "Old postgresql is installed." \
                        "Please uninstall postgreql and re-execute."
        fi
        # localhost に対して正しいアドレス情報を返すことをチェック
        if ! check_localhost; then
            abort_setup "The address of localhost is invalid." \
                        "Please make sure localhost in set in /etc/hosts"
        fi
    fi
}

check_cluster()
{
    if $EXTRA_MODE; then return 0; fi
    echo_title "Check cluster status."
    get_cluster_status
    if $CLUSTER_RUNNING; then
        # 冗長構成が実行中の場合
        #   マスターノードではインストールを禁止する
        #   スレーブノードでは --force オプションをチェックする
        if $CLUSTER_MASTER; then
            abort_setup "Pacemaker is runnning (MASTER), so cannot install." \
                        "To install, demote to slave or stop the pacemaker."
        elif ! $FORCE_MODE; then
            abort_setup "Pacemaker is runnning (SLAVE), so cannot install." \
                        "To install, use --force option."
        fi
    fi
}

get_python_sysconfig()
{
    local python=$1
    local config=$2
    $python -c "import sysconfig; print(sysconfig.get_config_var('$config'))" 2>&1
}

get_python_version()
{
    get_python_sysconfig $1 "py_version"
}

get_python_version_nodot()
{
    get_python_sysconfig $1 "py_version_nodot"
}

check_python()
{
    if ! $SKIP_PYTHON3_INSTALL; then
        disable_deprecated_repos
        install_python3
    fi
    echo_title "Check python version."
    local py_version=$(get_python_version $PYTHON)
    echo_info "PYTHON=$PYTHON ($py_version)"
    if [ $(ver2num $py_version) -lt $(ver2num $SUPPORTED_PYVER_MIN.000) ] ||
       [ $(ver2num $py_version) -gt $(ver2num $SUPPORTED_PYVER_MAX.999) ]; then
        abort_setup "Python $SUPPORTED_PYVER_MIN to $SUPPORTED_PYVER_MAX is required."
    fi
}

check_kompira_package()
{
    if $EXTRA_MODE; then return 0; fi
    local -x PIP=$(which pip 2> /dev/null)
    if [ -z "$PIP" ]; then
        return 0
    fi
    OLD_KOMPIRA_VERSION="$(get_kompira_version)"
    echo_info "VERSION=$OLD_KOMPIRA_VERSION [pip=$PIP]"
    case $OLD_KOMPIRA_VERSION in
        "")
            : # echo "*** Kompira はインストールされていません"
            ;;
        ${BRANCH}*)
            echo_info "A compatible version is installed."
            ;;
        *)
            abort_setup "An incompatible version is installed, so cannot update."
            ;;
    esac
}

check_update_kompira()
{
    echo_title "Check version of Kompira installed."

    # システム環境にインストールされた Kompira (obsoleted) をチェック
    check_kompira_package

    # virtualenv 環境にインストールされている Kompira をチェック
    PATH=$KOMPIRA_BIN/:$PATH check_kompira_package
}

check_update_kompira_jobmngr()
{
    local -x PATH=$KOMPIRA_BIN/:$PATH
    local -x PIP=$(which pip 2> /dev/null)
    KOMPIRA_VER=$(get_pip_info Kompira Version)
    case $KOMPIRA_VER in
        "")
            ;;
        *)
            if $FORCE_MODE; then
                echo_warn "Kompira is already installed."
            else
                abort_setup "Kompira is already installed."
            fi
    esac
}

check_update_kompira_sendevt()
{
    local -x PATH=$KOMPIRA_BIN/:$PATH
    local -x PIP=$(which pip 2> /dev/null)
    KOMPIRA_JOBMNGR_VER=$(get_pip_info Kompira_jobmngr Version)
    case $KOMPIRA_JOBMNGR_VER in
        "")
            ;;
        *)
            if $FORCE_MODE; then
                echo_warn "Kompira jobmngr is already installed."
            else
                abort_setup "Kompira jobmngr is already installed."
            fi
    esac
}

check_update_pgsql()
{
    echo_title "Check current PostgreSQL and Kompira database existence."
    #
    # 動作中の postgresql のバージョンをチェックする
    #
    echo_info "CUR_PG_BINDIR=$CUR_PG_BINDIR"
    echo_info "CUR_PG_DATADIR=$CUR_PG_DATADIR"
    echo_info "CUR_PG_SERVICE=$CUR_PG_SERVICE"
    echo_info "CUR_PG_VERSION=$CUR_PG_VERSION"
    echo_info "CUR_PG_MAJVER=$CUR_PG_MAJVER"
    if [ -z "$CUR_PG_MAJVER" ]; then
        return 0
    fi
    #
    # 既存 Kompira データベースの存在確認
    #
    if is_active_service $CUR_PG_SERVICE; then
        if $CUR_PSQL -U $PGSQL_USER -d $KOMPIRA_PG_DATABASE -c \\q; then
            LANG= $CUR_PSQL -U $PGSQL_USER -d $KOMPIRA_PG_DATABASE -c \\dt > $TMPDIR/pg_tables
            KOMPIRA_DB_TABLE_EXISTS=true
        fi
        if $CUR_PSQL -U $KOMPIRA_PG_USER -d $PGSQL_DB -c \\q; then
            KOMPIRA_DB_USER_EXISTS=true
        fi
    fi
    #
    # PostgreSQL のバージョン移行確認
    #
    if $POSTGRESQL_MIGRATE; then
        if $CLUSTER_RUNNING; then
            abort_setup "PostgreSQL migration (${CUR_PG_MAJVER}->${NEW_PG_MAJVER}) detected, but cannot migrate because clustering is running." \
                        "To install, stop the pacemaker in both systems."
        fi
        echo_info "Check free space for PostgreSQL migration"
        check_freespace $NEW_PG_DATADIR $CUR_PG_DATADIR $PG_MIGRATE_REQUIRE_FREERATE
        if ! $FORCE_MODE; then
            echo_warn "PostgreSQL migration (${CUR_PG_MAJVER}->${NEW_PG_MAJVER}) detected, Are you sure?"
            echo
            inquire "MIGRATE POSTGRESQL ${CUR_PG_MAJVER} TO ${NEW_PG_MAJVER} AND CONTINUE INSTALLATION? (yes/No)" "n"
            echo $answer
            echo
            if [ $answer != "y" ]; then
                abort_setup "Abort installation."
            fi
        else
            echo_info "PostgreSQL migration (${CUR_PG_MAJVER}->${NEW_PG_MAJVER}) detected"
        fi
        # TODO: Amazon Linux (非PDGD) 環境 では pg_upgrade による移行ができないためバックアップによるデータ移行を実施する
        if [ "$SYSTEM" == "AMZN" ]; then
            POSTGRESQL_UPGRADE=false
        fi
        # ダウングレードでは pg_upgrade は使えないため INITDATA_MODE=true にしてバックアップを実施する
        if ! $POSTGRESQL_UPGRADE; then
            INITDATA_MODE=true
        fi
        CLUSTER_FULLSTOP_UPGRADE=true
        # バージョン移行の場合は、以下の確認は不要
        return 0
    fi
    #
    # INITDATA モードでは Kompira データベースが存在する場合、消してよいか確認する
    #
    if $INITDATA_MODE; then
        # 強制モードでは既存ユーザ／データベースがあっても継続する
        if $KOMPIRA_DB_TABLE_EXISTS; then
            echo_warn "Kompira Database '$KOMPIRA_PG_DATABASE' is exist already"
        fi
        if $KOMPIRA_DB_USER_EXISTS; then
            echo_warn "Kompira DB-user '$KOMPIRA_PG_USER' is exist already"
        fi
        if ! $FORCE_MODE && ($KOMPIRA_DB_TABLE_EXISTS || $KOMPIRA_DB_USER_EXISTS); then
            echo
            inquire "DELETE AND CONTINUE INSTALLATION? (yes/No)" "n"
            echo $answer
            echo
            if [ $answer != "y" ]; then
                abort_setup "Abort installation."
            fi
        fi
    fi
}

check_update_rabbitmq()
{
    echo_title "Check Erlang/RabbitMQ version."
    # インストールされている rabbitmq-server のバージョンをチェックする
    OLD_RABBITMQ_VERSION=$(get_rpm_version rabbitmq-server)
    OLD_ERLANG_VERSION=$(get_rpm_version erlang)
    echo_info "OLD_RABBITMQ_VERSION=$OLD_RABBITMQ_VERSION"
    echo_info "OLD_ERLANG_VERSION=$OLD_ERLANG_VERSION"
    # 現 rabbitmq-server の機能フラグをチェックする（シングル構成の場合）
    if ! $CLUSTER_CONFIGURED && [ -n "$OLD_RABBITMQ_VERSION" ]; then
        echo_info "Check feature flags in rabbitmq-server (old)"
        local rmq_started=false
        is_active_service
        if rabbitmqctl ping --silent 2> /dev/null; then
            rmq_started=true
        else
            _service_start rabbitmq-server
            if [ $? != 0 ]; then
                echo_warn "Failed to start rabbitmq-server"
                RABBITMQ_WIPE_DATA=true
            fi
        fi
        if rabbitmqctl ping --silent 2> /dev/null; then
            verbose_run rabbitmqctl list_feature_flags --silent | tee $TMPDIR/rabbitmq-feature_flags.old
            if grep -q 'disabled$' $TMPDIR/rabbitmq-feature_flags.old; then
                echo_info "Enable all feature flags in rabbitmq-server before updating"
                verbose_run rabbitmqctl enable_feature_flag all
                if [ $? != 0 ]; then
                    echo_warn "Failed to enable feature flags"
                    RABBITMQ_WIPE_DATA=true
                fi
            else
                echo_info "All feature flags are already enabled"
            fi
        fi
        if ! $rmq_started; then
            _service_stop rabbitmq-server
        fi
    fi
}

check_update()
{
    if $EXTRA_MODE; then return 0; fi
    if $JOBMNGR_MODE; then
        check_update_kompira_jobmngr
    elif $SENDEVT_MODE; then
        check_update_kompira_jobmngr
        check_update_kompira_sendevt
    else
        # 実行中の pgsql のバージョンおよび既存データベースをチェックする
        check_update_pgsql
        # インストールされている rabbitmq のバージョンをチェックする
        check_update_rabbitmq
        # インストールされている Kompira の互換性チェックする
        check_update_kompira
        # Kompira がインストールされていないなら、Pacemaker がインストール済みであっても
        # シングル構成で Kompira を新規インストールできるようにする。
        if $CLUSTER_CONFIGURED && ! $CLUSTER_RUNNING && [ ! -f /usr/lib/systemd/system/kompirad.service ]; then
            echo_info "Since Kompira is not installed, we will set it up as a single configuration."
            CLUSTER_CONFIGURED=false
        fi
    fi
}

check_license()
{
    if $JOBMNGR_MODE || $SENDEVT_MODE; then return 0; fi
    if $CLUSTER_RUNNING; then return 0; fi
    if [ -z "$OLD_KOMPIRA_VERSION" ]; then
        return 0
    fi
    if $INITDATA_MODE || ! $KOMPIRA_DB_TABLE_EXISTS; then
        return 0
    fi
    # 導入されているライセンスをチェックする
    echo_title "Check installed licence of Kompira"
    if [ -f $KOMPIRA_VAR_DIR/startup/do_migrate ]; then
        echo_info "Database migration not yet applied. (SKIP)"
        return 0
    fi
    if ! grep -qF kompira_baseobject $TMPDIR/pg_tables; then
        echo_warn "Database table is not found: kompira_baseobject"
        return 0
    fi
    # 現在のタイムゾーンに一致しない /etc/sysconfig/clock が存在していると、
    # manage.py がエラーになるため、明示的に TZ 環境変数を指定しておく。
    local current_timezone=$(LANG= timedatectl status | sed -nre '/Time zone:/s|.*: (\S*).*|\1|p')
    if [ -z "$current_timezone" ] || [ "$current_timezone" == "n/a" ]; then
        current_timezone="UTC"
    fi
    TZ=$current_timezone verbose_run $KOMPIRA_BIN/manage.py license_info
    if [ $? != 0 ]; then
        if ! $FORCE_MODE; then
            abort_setup "The installed license is invalid."
        fi
    fi
}

check_locale_lang()
{
    local lang=(${LOCALE_LANG/./ })
    local country=${lang[0]}
    local enc=${lang[1],,}
    enc=${enc/-/}
    if [ "$enc" != "utf8" ]; then
       abort_setup "Only UTF-8 encoding is supported for LOCALE_LANG (specified '$LOCALE_LANG')."
    fi
    for loc in $(localectl list-locales); do
        local loc_lang=(${loc/./ })
        local loc_country=${loc_lang[0]}
        local loc_enc=${loc_lang[1],,}
        loc_enc=${loc_enc/-/}
        if [ "$country" = "$loc_country" ] && [ "$enc" = "$loc_enc" ]; then
            if [[ "$LOCALE_LANG" != "$(get_locale_info)" ]]; then
                echo_title "Set LC_CTYPE category"
                # SSH 接続元によっては LC_CTYPE が不正になる場合があるので LOCALE_LANG と同じ値を設定しておく
                verbose_run export LC_CTYPE="$LOCALE_LANG"
            fi
            echo_param "LC_CTYPE" "$(get_locale_info)"
            return 0
        fi
    done
    abort_setup "The specified LOCALE_LANG '$LOCALE_LANG' is not included in the system locale list. Please install the corresponding language pack if necessary."
}

check_installed_versions()
{
    echo_title "Check installed versions"
    #
    # postgresql の新しい NEW_PG_BINDIR とバージョンを判定する
    #
    NEW_PG_EXECSTART=$($SYSTEMCTL cat $NEW_PG_SERVICE | grep '^ExecStart=' | sed -re 's/ExecStart=//' | cut -d' ' -f1)
    if [ -z "$NEW_PG_EXECSTART" ]; then
        abort_setup "NEW_PG_EXECSTART($NEW_PG_EXECSTART) could not be confirmed!"
    fi
    NEW_PG_BINDIR=$(dirname $(readlink -f $NEW_PG_EXECSTART))
    echo_info "Detected NEW_PG_BINDIR=$NEW_PG_BINDIR"
    NEW_POSTGRES=$NEW_PG_BINDIR/postgres
    if ! [ -x $NEW_POSTGRES ]; then
        abort_setup "NEW_POSTGRES($NEW_POSTGRES) is not executable!"
    fi
    NEW_PG_VERSION=$($NEW_POSTGRES --version | sed -re 's|.* ([0-9.]+).*|\1|')
    echo_info "Detected NEW_PG_VERSION=$NEW_PG_VERSION"

    # erlang/rabbitmq-server のバージョンチェック
    NEW_RABBITMQ_VERSION=$(get_rpm_version rabbitmq-server)
    NEW_ERLANG_VERSION=$(get_rpm_version erlang)
    if [ $(ver2num $NEW_RABBITMQ_VERSION) -lt $(ver2num "${SUPPORTED_RMQVER_MIN}.0") ]; then
        abort_setup "The installed rabbitmq-server is too old: $NEW_RABBITMQ_VERSION"
    fi
    # erlang バージョンアップ時の互換性チェック
    if [ -n "$OLD_ERLANG_VERSION" ]; then
        if [ ${OLD_ERLANG_VERSION:0:1} == "R" ]; then
            # erlang が古すぎて互換性無し（Ferora Project を使っていた場合など）。
            RABBITMQ_WIPE_DATA=true
            CLUSTER_FULLSTOP_UPGRADE=true
        fi
    fi
    # rabbitmq-server バージョンアップ時の互換性チェック
    local NEW_RMQ=(${NEW_RABBITMQ_VERSION//./ })
    if [ -n "$OLD_RABBITMQ_VERSION" ]; then
        local OLD_RMQ=(${OLD_RABBITMQ_VERSION//./ })
        # バージョン X.Y.Z の X と Y 部分の差分を計算
        local RMQ_MAJ_VUP=$((${NEW_RMQ[0]} - ${OLD_RMQ[0]}))
        local RMQ_MIN_VUP=$((${NEW_RMQ[1]} - ${OLD_RMQ[1]}))
        # マイナーバージョンが変わっているかチェック
        if [ $RMQ_MAJ_VUP -ne 0 ] || [ $RMQ_MIN_VUP -ne 0 ]; then
            RABBITMQ_UPGRADED=true
        fi
        # マイナーバージョンをチェックして、以下に該当する場合は
        # 起動に失敗する可能性があるのでデータ領域 (mnesia) を削除する
        # - rabbitmq-server がバージョンスキップ（またはダウングレード）している
        # - rabbitmq-server が古すぎる（上の Fedora チェックに該当するはず）
        if [ $RMQ_MAJ_VUP -ne 0 ] || [ $RMQ_MIN_VUP -gt 1 ] || [ $RMQ_MIN_VUP -lt 0 ] || [ $(ver2num $OLD_RABBITMQ_VERSION) -lt $(ver2num "${SUPPORTED_RMQVER_MIN}.0") ]; then
            echo_info "Detected an update to rabbitmq-server that required erasure of the data area: $OLD_RABBITMQ_VERSION -> $NEW_RABBITMQ_VERSION"
            RABBITMQ_WIPE_DATA=true
            CLUSTER_FULLSTOP_UPGRADE=true
        fi
    fi
    # rabbitmq-server が最新版であるかチェック
    get_available_rabbitmq_version
    local RMQ_MIN_VUP1=${NEW_RMQ[0]}.$((${NEW_RMQ[1]} + 1))
    if [[ "$RABBITMQ_AVAILABLE_VERSIONS" =~ $RMQ_MIN_VUP1 ]]; then
        RABBITMQ_AVAILABLE_NEWER=true
    fi
}

yum_clean()
{
    if $SKIP_CLEAN_YUM_CACHE; then return 0; fi
    echo_title "Clean yum cache."

    # 古いレポジトリを無効にする
    disable_deprecated_repos

    # 重複パッケージを削除する
    verbose_run package-cleanup -y --cleandupes --removenewestdupes

    # yum check-upate がキャッシュを参照しないようにクリアしておく
    verbose_run yum clean all > /dev/null

    if ! $OFFLINE_MODE; then
        echo_info "Check yum update."
        verbose_run yum -q check-update > /dev/null
        if [ "$?" -eq 1 ]; then
            echo_error "[ERROR] Can not connect to yum repository."
            echo_error "Please make sure this server can connect to the internet. Or check the proxy settings."
            abort_setup
        fi
    fi
}

configure_locale_lang()
{
    if ! $CONFIG_LOCALE_LANG; then return 0; fi
    if $EXTRA_MODE; then return 0; fi

    echo_title "Check locale language settings"
    if LANG= localectl status | grep -q -F "Locale: LANG=$LOCALE_LANG"; then
        echo_info "Confirmed language: $LOCALE_LANG"
    else
        echo_info "Change language setting ($LANG -> $LOCALE_LANG)"
        verbose_run localectl set-locale LANG=$LOCALE_LANG
        LANG=$LOCALE_LANG
    fi
}

configure_locale_timezone()
{
    if $EXTRA_MODE; then return 0; fi

    echo_title "Check locale timezone settings"
    local current_timezone=$(LANG= timedatectl status | sed -nre '/Time zone:/s|.*: (\S*).*|\1|p')
    if ! $CONFIG_LOCALE_TIMEZONE; then
        echo_info "Current timezone: $current_timezone"
    elif [ "$current_timezone" == "$LOCALE_TIMEZONE" ]; then
        echo_info "Confirmed timezone: $LOCALE_TIMEZONE"
    else
        echo_info "Change timezone settings ($current_timezone -> $LOCALE_TIMEZONE)"
        verbose_run timedatectl set-timezone $LOCALE_TIMEZONE
        current_timezone=$LOCALE_TIMEZONE
    fi
    # 現在のタイムゾーンに一致しない /etc/sysconfig/clock が存在していると、
    # manage.py がエラーになるため、現在のタイムゾーンに合わせて /etc/sysconfig/clock を修正しておく。
    if [ -f /etc/sysconfig/clock ] && [ "$current_timezone" != "n/a" ]; then
        (
            . /etc/sysconfig/clock
            if [ "$ZONE" != "$current_timezone" ]; then
                echo_info "Change /etc/sysconfig/clock ($ZONE -> $current_timezone)"
                (echo -e "ZONE=\"$current_timezone\"\nUTC=false"; sed -re '/^(ZONE|UTC)=/d' /etc/sysconfig/clock) > $TMPDIR/clock
                diff_cp $TMPDIR/clock /etc/sysconfig/clock
            fi
        )
    fi
}

create_user()
{
    echo_title "Create Kompira account: $KOMPIRA_USER"
    if ! id $KOMPIRA_USER > /dev/null 2>&1; then
        verbose_run useradd -s $KOMPIRA_LOGIN $KOMPIRA_USER
    else
        verbose_run usermod -s $KOMPIRA_LOGIN $KOMPIRA_USER
    fi
    #
    # .bash_profile に virtualenv を activate する設定を追加
    # MEMO: チルダ展開の前にパラメータ展開するため eval で展開
    #
    local BASH_PROFILE=$(eval "echo ~$KOMPIRA_USER/.bash_profile")
    cp $BASH_PROFILE $TMPDIR/bash_profile

    if grep -E -i -q "^export http?_proxy=" $TMPDIR/bash_profile; then
        verbose_run \
            sed -i -r \
            -e "s|^(export https?_proxy)=.*|\1='$PROXY_URL'|i" \
            -e "s|^(export no_proxy)=.*|\1='$NO_PROXY'|" \
            $TMPDIR/bash_profile
    else
        cat >> $TMPDIR/bash_profile <<EOF

# proxy settings
export http_proxy='$PROXY_URL'
export https_proxy='$PROXY_URL'
export HTTP_PROXY='$PROXY_URL'
export HTTPS_PROXY='$PROXY_URL'
export no_proxy='$NO_PROXY'
EOF
    fi
    if ! grep -q -F "source $KOMPIRA_BIN/activate" $TMPDIR/bash_profile; then
        cat >> $TMPDIR/bash_profile <<EOF

# activate virtualenv
if [ -f $KOMPIRA_BIN/activate ]; then
    source $KOMPIRA_BIN/activate
fi
EOF
    fi
    diff_install -o $KOMPIRA_USER -g $KOMPIRA_GROUP $TMPDIR/bash_profile $BASH_PROFILE
}

create_home()
{
    echo_title "Create Kompira directory: $KOMPIRA_HOME"
    verbose_run $INSTALL -m 755 -d $KOMPIRA_HOME
}

create_virtualenv()
{
    echo_title "Create virtualenv: $KOMPIRA_ENV"
    #
    # python3 の venv 作成(pip も合わせてインストールされる)
    #
    local venv_options=""
    $PYTHON -m venv $venv_options $KOMPIRA_ENV
    exit_if_failed "$?" "Failed to create virtualenv"
    # virtualenv の pip 用 proxy 設定
    echo -e "[global]\nproxy=$PROXY_URL" > $TMPDIR/kompira_pip.conf
    if ! diff -N -u $KOMPIRA_ENV/pip.conf $TMPDIR/kompira_pip.conf; then
        verbose_run cp -S .old -b $TMPDIR/kompira_pip.conf $KOMPIRA_ENV/pip.conf
    fi
}

activate_virtualenv()
{
    source $KOMPIRA_ENV/bin/activate
}

deactivate_virtualenv()
{
    deactivate
}

disable_deprecated_repos()
{
    # 古いリポジトリを無効にする
    for repo in $DEPRECATED_REPOS; do
        verbose_run yum-config-manager --disable $repo 2> /dev/null > /dev/null 
    done
}

install_python3()
{
    echo_title "Install Python 3.X package"
    local installed_python_version
    if [ -f $KOMPIRA_BIN/python ]; then
        installed_python_version=$(get_python_version $KOMPIRA_BIN/python)
        echo_info "Current Python ($KOMPIRA_BIN/python): $installed_python_version"
        if [ $(ver2num $installed_python_version) -lt $(ver2num 3.7) ] && ! $EXTRA_MODE; then
            echo_warn "Skip Python update because an older version of Python is installed."
            PYTHON=$KOMPIRA_BIN/python
            return
        fi
    fi
    if [ -z "$PYTHON_VERSION" ]; then
        if [ -n "$installed_python_version" ]; then
            PYTHON_VERSION=$(echo $installed_python_version | sed -re 's/([0-9])\.([0-9]+).*/\1.\2/')
        else
            # Choice recommended python version
            local available_pyvers="$($THIS_DIR/scripts/python_utils.sh available)"
            echo_info "Available Python versions: $available_pyvers"
            set $available_pyvers
            PYTHON_VERSION="$1"
        fi
        echo_info "Recommended Python: $PYTHON_VERSION"
    fi
    local python_utils_options="$PYTHON_VERSION"
    if $EXTRA_MODE; then
        python_utils_options="--without-debuginfo all"
    elif $OFFLINE_MODE; then
        python_utils_options="$python_utils_options --offline"
    elif ! $WITH_GDB; then
        python_utils_options="$python_utils_options --without-debuginfo"
    fi
    #
    # Install the recommended version of Python(s).
    # TODO: install python debuginfo
    #
    verbose_run $THIS_DIR/scripts/python_utils.sh install $python_utils_options
    exit_if_failed "$?" "Failed to install python $PYTHON_VERSION"
    local python_path=$($THIS_DIR/scripts/python_utils.sh which $PYTHON_VERSION)
    if [ -z "$python_path" ]; then
        abort_setup "Python $$PYTHON_VERSION is not found!"
    elif [ ! -x $python_path ]; then
        abort_setup "$python_path is not executable!"
    fi
    installed_python_version=$(get_python_version $python_path)
    if [ "$PYTHON_VERSION" != $(echo $installed_python_version | sed -re 's/([0-9])\.([0-9]+).*/\1.\2/') ]; then
        abort_setup "The installed Python version ($installed_python_version) is not as expected! ($PYTHON_VERSION was expected)"
    fi
    echo_info "Python version was checked: $PYTHON_VERSION ($installed_python_version)"
    PYTHON=$python_path
}

enable_amazon2_extra_packages()
{
    echo_info "Enable Amazon Linux 2 Extra packages (epel/postgresql${NEW_PG_MAJVER})"
    PYTHON=$PLATFORM_PYTHON verbose_run amazon-linux-extras enable epel
    #
    # PG_YUMREPO は /etc/redhat-release が必要となるため、インストールできない。
    # Amazon Linux 標準の extra パッケージから postgresql${NEW_PG_MAJVER} をインストールする
    #
    local topic
    for topic in $(PYTHON=$PLATFORM_PYTHON amazon-linux-extras list | grep -Eo "postgresql[0-9]*"); do
        if [ $topic != "postgresql${NEW_PG_MAJVER}" ]; then
            PYTHON=$PLATFORM_PYTHON verbose_run amazon-linux-extras disable "$topic" > /dev/null
        fi
    done
    PYTHON=$PLATFORM_PYTHON verbose_run amazon-linux-extras enable "postgresql${NEW_PG_MAJVER}"
}

enable_amazon2023_extra_packages()
{
    # Amazon Linux 2023 では amazon-linux-extras が廃止されている
    echo_info "Enable Amazon Linux 2023"
}

install_epel_repo()
{
    echo_info "Install Yum repositories (EPEL)"
    local epel_yumrepo
    case $SYSTEM in
    RHEL|MIRACLE)
        if [ $RHEL_VERSION == 7 ]; then
            # install archived EPEL7 repository
            epel_yumrepo=$EPEL7_YUMREPO
        else
            epel_yumrepo=$EPEL_YUMREPO
        fi
        yum_localinstall "$epel_yumrepo"
        exit_if_failed "$?" "Failed to install repository: $epel_yumrepo"
        ;;
    *)
        YUM_OPTION="--disablerepo=pgdg*" yum_install $EPEL_REPOPKG
        exit_if_failed "$?" "Failed to install repository: $EPEL_REPOPKG"
        ;;
    esac
}

install_rabbitmq_repo()
{
    # https://www.rabbitmq.com/docs/3.13/install-rpm
    if [ -f /etc/yum.repos.d/rabbitmq_erlang.repo ] || [ -f /etc/yum.repos.d/rabbitmq_rabbitmq-server.repo ]; then
        echo_info "Disable the packagecloud repository that is no longer in use."
        verbose_run yum-config-manager --disable "rabbitmq_erlang*" > /dev/null
        verbose_run yum-config-manager --disable "rabbitmq_rabbitmq-server*" > /dev/null
    fi
    echo_info "Install rabbitmq repository for erlang/rabbitmq-server"
    if [ $RHEL_VERSION == 8 ]; then
        diff_cp $THIS_DIR/config/yum.repos.d/rabbitmq-el8.repo /etc/yum.repos.d/rabbitmq.repo
    elif [ $RHEL_VERSION == 9 ]; then
        diff_cp $THIS_DIR/config/yum.repos.d/rabbitmq-el9.repo /etc/yum.repos.d/rabbitmq.repo
    elif [ -n "$OLD_RABBITMQ_VERSION" ]; then
        echo_warn "It is not possible to update erlang/rabbitmq-server due to unsupported operating systems."
        SKIP_RABBITMQ_UPDATE=true
        return
    elif [ ! -f /etc/yum.repos.d/rabbitmq.repo ]; then
        abort_setup "Failed to install rabbitmq repository."
    fi
}

setup_package_repository()
{
    if [ $SYSTEM == "AMZN" ]; then
        if [ $SYSTEM_NAME == "amzn2023" ]; then
            enable_amazon2023_extra_packages
        else
            enable_amazon2_extra_packages
        fi
    else
        install_epel_repo
        install_pgdg_redhat_repo
    fi
    verbose_run yum-config-manager --enable $EPEL_REPONAME > /dev/null
    if [ $SYSTEM != "AMZN" ]; then
        # [pgdg${NEW_PG_MAJVER}] が /etc/yum.repos.d/pgdg*.repo に存在しない場合は、
        # postgresql のアップデートはできないと判断して、SKIP_POSTGRESQL_UPDATE=true とする
        if ! grep -F "[pgdg${NEW_PG_MAJVER}]" /etc/yum.repos.d/pgdg*.repo > /dev/null; then
            echo_warn "PGDG repository for postgresql-${NEW_PG_MAJVER} is not found."
            SKIP_POSTGRESQL_UPDATE=true
        else
            verbose_run yum-config-manager --disable pgdg* > /dev/null
            verbose_run yum-config-manager --enable pgdg-common > /dev/null
            verbose_run yum-config-manager --enable "pgdg${NEW_PG_MAJVER}" > /dev/null
            if [ $RHEL_VERSION -ge 8 ]; then
                # PGDG リポジトリからパッケージをダウンロードできるかをチェックする (pgdg17 における $releasever 問題対策)
                echo_info "Check PGDG repository"
                local YUM_RELEASEVER=$(cat /etc/yum/vars/releasever 2>/dev/null)
                echo_info "YUM_RELEASEVER=$YUM_RELEASEVER"
                verbose_run yum -q -y download --url --disablerepo=* --enablerepo="pgdg${NEW_PG_MAJVER}" "$NEW_PG_PREFIX*"
                if [ $? != 0 ]; then
                    if [ "$YUM_RELEASEVER" != "$RHEL_VERSION" ] && grep -q "\\\$releasever" /etc/yum.repos.d/pgdg*.repo; then
                        verbose_run sed -i.orig -re "s/\\\$releasever/${RHEL_VERSION}/g" /etc/yum.repos.d/pgdg*.repo
                    else
                        abort_setup "Failed to download the package from the PGDG repository."
                    fi
                fi
            fi
        fi
    fi
    if [ -n "$OPTION_REPONAME" ]; then
        verbose_run yum-config-manager --enable "$OPTION_REPONAME" > /dev/null
    fi
    install_rabbitmq_repo
    if [ $RHEL_VERSION -ge 8 ]; then
        verbose_run yum -y module disable "postgresql"
    fi
}

install_requires_prepare()
{
    echo_title "Install RPM packages for preparation"
    local yum_option=$YUMOPT_INSTALL
    # 事前にアップデートが必要なパッケージはアップデートする
    if $OFFLINE_MODE; then
        yum_option="$yum_option --noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
    fi
    verbose_run yum $yum_option -y update --disablerepo=pgdg* $PACKAGES_FOR_UPDATE
    YUM_OPTION="$YUMOPT_INSTALL --disablerepo=pgdg*" yum_install $PACKAGES_FOR_INSTALL
}

install_requires_sendevt()
{
    echo_title "Install RPM packages for Kompira-sendevt"
    local packages_for_sendevt=$PACKAGES_FOR_SENDEVT
    local yum_options=$YUMOPT_SENDEVT
    if ! $OFFLINE_MODE; then
        packages_for_sendevt="$packages_for_sendevt $PACKAGES_FOR_SENDEVT_BUILD"
    fi
    YUM_OPTION=$yum_options yum_install $packages_for_sendevt
}

install_requires_jobmngrd()
{
    echo_title "Install RPM packages for Kompira-jobmngr"
    #
    # オフラインモードでないときは必要なリポジトリを有効にする
    #
    local packages_for_sendevt=$PACKAGES_FOR_SENDEVT
    local packages_for_jobmngr=$PACKAGES_FOR_JOBMNGR
    local yum_options
    if ! $OFFLINE_MODE; then
        if [ -n "$OPTION_REPONAME" ]; then
            verbose_run yum-config-manager --enable "$OPTION_REPONAME" > /dev/null
        fi
        packages_for_sendevt="$packages_for_sendevt $PACKAGES_FOR_SENDEVT_BUILD"
        packages_for_jobmngr="$packages_for_jobmngr $PACKAGES_FOR_JOBMNGR_BUILD $PACKAGES_FOR_BUILD"
    fi
    YUM_OPTION=$yum_options yum_install $packages_for_sendevt $packages_for_jobmngr
}

install_requires_kompira()
{
    echo_title "Install RPM packages for Kompira"
    #
    # オフラインモードでないときは必要なリポジトリをインストール／有効化する
    #
    local packages_for_sendevt=$PACKAGES_FOR_SENDEVT
    local packages_for_jobmngr=$PACKAGES_FOR_JOBMNGR
    local packages_for_kompira=$PACKAGES_FOR_KOMPIRA
    local packages_for_kompira_rabbitmq
    local packages_for_kompira_postgresql
    local packages_for_build=""
    local with_packages=$WITH_RPM
    local yum_options
    if ! $OFFLINE_MODE; then
        # パッケージリポジトリのセットアップ
        setup_package_repository
        # mod-wsgiをコンパイルするために必要
        packages_for_kompira+=" redhat-rpm-config"
    fi
    #
    # インストールする rabbitmq-server のバージョンとパッケージ名を特定
    #
    get_available_rabbitmq_version
    if [ -n "$RABBITMQ_SPEC_VERSION" ]; then
        packages_for_kompira_rabbitmq="rabbitmq-server-$RABBITMQ_SPEC_VERSION"
    elif [ -n "$OLD_RABBITMQ_VERSION" ]; then
        if $SKIP_RABBITMQ_UPDATE; then
            # rabbitmq-server のアップデートをスキップする
            packages_for_kompira_rabbitmq=""
        elif $CLUSTER_CONFIGURED; then
            # 冗長構成では rabbitmq-server はマイナーバージョン+1までのアップデートを許容する
            local OLD_RMQ=(${OLD_RABBITMQ_VERSION//./ })
            local RMQ_MIN_VUP0=${OLD_RMQ[0]}.$((${OLD_RMQ[1]} + 0))
            local RMQ_MIN_VUP1=${OLD_RMQ[0]}.$((${OLD_RMQ[1]} + 1))
            if [ $(ver2num $OLD_RABBITMQ_VERSION) -lt $(ver2num "${SUPPORTED_RMQVER_MIN}.0") ]; then
                # アップデート前のバージョンが古すぎる場合は最新版をインストールする（要両系停止）
                echo_warn "The current rabbitmq-server ($OLD_RABBITMQ_VERSION) is too old and will attempt to update to the latest version."
                packages_for_kompira_rabbitmq="rabbitmq-server-$RABBITMQ_LATEST_VERSION.*"
            elif [ $(ver2num $OLD_RABBITMQ_VERSION) -gt $(ver2num "${SUPPORTED_RMQVER_MAX}.999") ]; then
                # アップデート前のバージョンが新しすぎる場合は rabbitmq-server のアップデートをスキップする
                echo_warn "The current rabbitmq-server ($OLD_RABBITMQ_VERSION) is too new and skip the update."
                packages_for_kompira_rabbitmq=""
            elif [[ "$RABBITMQ_AVAILABLE_VERSIONS" =~ $RMQ_MIN_VUP1 ]]; then
                packages_for_kompira_rabbitmq="rabbitmq-server-$RMQ_MIN_VUP1.*"
            elif [[ "$RABBITMQ_AVAILABLE_VERSIONS" =~ $RMQ_MIN_VUP0 ]]; then
                packages_for_kompira_rabbitmq="rabbitmq-server-$RMQ_MIN_VUP0.*"
            else
                # 現在のマイナーバージョンが利用できない場合は最新版をインストールする（要両系停止）
                echo_warn "Unable to update rabbitmq-server with consecutive versions."
                packages_for_kompira_rabbitmq="rabbitmq-server-$RABBITMQ_LATEST_VERSION.*"
            fi
        else
            # シングル構成では最新版までアップデートできる
            packages_for_kompira_rabbitmq="rabbitmq-server-$RABBITMQ_LATEST_VERSION.*"
        fi
    else
        # 新規インストール時は最新版をインストールする
        packages_for_kompira_rabbitmq="rabbitmq-server-$RABBITMQ_LATEST_VERSION.*"
    fi
    #
    # インストールする postgresql のバージョンとパッケージ名を特定
    # TODO: latest バージョンの確認
    # TODO: 指定バージョンが利用可能かの確認
    #
    if [ -n "$POSTGRESQL_SPEC_VERSION" ]; then
        packages_for_kompira_postgresql=" $NEW_PG_PREFIX-server-$POSTGRESQL_SPEC_VERSION $NEW_PG_PREFIX-contrib-$POSTGRESQL_SPEC_VERSION"
    else
        packages_for_kompira_postgresql=" $NEW_PG_PREFIX-server-$NEW_PG_MAJVER.* $NEW_PG_PREFIX-contrib-$NEW_PG_MAJVER.*"
    fi
    if [ -n "$CUR_PG_MAJVER" ] && ! $POSTGRESQL_MIGRATE && $SKIP_POSTGRESQL_UPDATE; then
        # postgresql のアップデートをスキップする
        packages_for_kompira_postgresql=""
    fi
    if ! $OFFLINE_MODE; then
        packages_for_build="$PACKAGES_FOR_BUILD $PACKAGES_FOR_SENDEVT_BUILD $PACKAGES_FOR_JOBMNGR_BUILD $PACKAGES_FOR_KOMPIRA_BUILD"
    fi
    if $WITH_GDB; then
        with_packages="$with_packages $PACKAGES_FOR_GDB"
    fi

    YUM_OPTION=$yum_options yum_install $packages_for_sendevt $packages_for_jobmngr \
              $packages_for_kompira $packages_for_kompira_rabbitmq $packages_for_kompira_postgresql \
              $PACKAGES_FOR_SELINUX $packages_for_build $PACKAGES_FOR_SETUP_CLUSTER $with_packages

    if $WITH_GDB; then
        if [ $SYSTEM_NAME == "cent8" ]; then
            yum_options="--enablerepo=debuginfo"
        elif [ $SYSTEM_NAME == "rocky8" ]; then
            yum_options="--enablerepo=*debug*"
        fi
        YUM_OPTION=$yum_options debuginfo_install $DEBUGINFO
    fi
}

stop_kompira()
{
    if $CLUSTER_RUNNING; then return 0; fi
    echo_title "Stop Kompira daemon and others"
    _service_stop kompirad
    _service_stop kompira_jobmngrd
    _service_stop rabbitmq-server
}

uninstall_kompira_package()
{
    local -x PIP=$(which pip 2> /dev/null)
    if [ -z "$PIP" ]; then
        return 0
    fi
    echo_title "Uninstall old Kompira packages [pip=$PIP]"
    pip_uninstall_if_installed $KOMPIRA_PKGNAME_DEFAULT $KOMPIRA_PKGNAME_JOBMNGR $KOMPIRA_PKGNAME_SENDEVT
}

uninstall_kompira()
{
    #
    # localenv 環境以前の kompira をアンインストール
    #
    uninstall_kompira_package

    #
    # localenv 環境対応の kompira をアンインストール
    #
    local -x PATH=$KOMPIRA_BIN:$PATH
    uninstall_kompira_package
}

uninstall_packages()
{
    # 古い erlang/rabbitmq-server をアンインストール
    if ! $SENDEVT_MODE; then
        echo_title "Uninstall the old Erlang/RabbitMQ if it's installed."
        # Ferora Project の Erlang がインストールされていればアンインストールする
        if rpm -qa --qf "%{VENDOR}: %{NAME}-%{VERSION}-%{RELEASE}\n" "erlang*" | grep -F "Fedora Project:"; then
            echo_info "Uninstall old erlang packages"
            verbose_run yum $YUM_OPTION -y erase "erlang*"
            exit_if_failed "$?" "Failed to uninstall erlang"
        fi
    fi
}

install_whl_package()
{
    local pkg_file=$1
    local pkg_name=$(basename $pkg_file)
    local pip_options
    shift
    if $OFFLINE_MODE; then
        local py_version_nodot=$(get_python_version_nodot $KOMPIRA_BIN/python)
        local wheelhouse_name="wheelhouse-py${py_version_nodot}"
        pip_options="--no-index --find-links=$KOMPIRA_EXTRA_BASE/$wheelhouse_name"
    fi
    if [ -n "$TEMP_PROXY_URL" ]; then
        pip_options="$pip_options --proxy=$TEMP_PROXY_URL"
    fi
    #
    # sudo -u kompira pip が展開した whl ファイルにアクセスできないので一旦 /tmp にコピーする
    # pip install でインストールするパッケージのビルト時に必要になる場合があるので PATH 環境変数を渡す
    #
    local user_tmpdir=$(sudo -u $KOMPIRA_USER mktemp -d)
    verbose_run cp $pkg_file $user_tmpdir/$pkg_name
    verbose_run $KOMPIRA_BIN/pip install $pip_options -U pip wheel setuptools
    (cd / && PATH=$PATH verbose_run $KOMPIRA_BIN/pip install $pip_options $user_tmpdir/$pkg_name $@)
    local rc=$?
    verbose_run rm -rf $user_tmpdir
    return $rc
}

get_kompira_wheel_file()
{
    local src_wheel_file=$1
    local py_version_nodot=$2
    # $KOMPIRA_BIN/python のバージョンに合わせてインストールする wheel ファイルを選択する
    if [ -z "$py_version_nodot" ]; then
        py_version_nodot=$(get_python_version_nodot $KOMPIRA_BIN/python)
    fi
    # コンパイル済み wheel ファイルがあればそれを使う
    local bin_wheel_file="${src_wheel_file/py3-none-any/py${py_version_nodot}-none-any}"
    if [ -f $bin_wheel_file ]; then
        echo $bin_wheel_file
    elif [ -f $src_wheel_file ]; then
        echo $src_wheel_file
    else
        abort_setup "Neither $src_wheel_file nor $bin_wheel_file is found!"
    fi
}

install_package_sendevt()
{
    echo_title "Install Kompira-sendevt package"
    install_whl_package $(get_kompira_wheel_file $KOMPIRA_WHLFILE_SENDEVT)
    exit_if_failed "$?" "Failed to install Kompira-sendevt package"
}

install_package_jobmngr()
{
    echo_title "Install Kompira-jobmngr package"
    install_whl_package $(get_kompira_wheel_file $KOMPIRA_WHLFILE_JOBMNGR)
    exit_if_failed "$?" "Failed to install Kompira-jobmngr package"
}

install_package_default()
{
    echo_title "Install Kompira package"
    #
    # LANG=C/C.UTF-8 の場合、パッケージインストール時に失敗する可能性があるので LOCALE_LANG の値をセットしておく
    # (cf. https://github.com/fixpoint/kompira-v16/issues/1601)
    #
    LANG=$LOCALE_LANG install_whl_package $(get_kompira_wheel_file $KOMPIRA_WHLFILE_DEFAULT) $WITH_WHL
    exit_if_failed "$?" "Failed to install Kompira package"
    # setup_utils.sh の VERSION/BRANCH を更新する
    # TODO: 本来は whl パッケージ作成時に更新したい
    verbose_run sed -i -e "/^BRANCH=/c BRANCH=$BRANCH" -e "/^VERSION=/c VERSION=$VERSION" -e "/^SHORT_VERSION=/c SHORT_VERSION=$SHORT_VERSION" $KOMPIRA_BIN/setup_utils.sh
    # 管理コマンドの実行可能ユーザを root ユーザまたは kompira グループに所属するユーザに制限する
    verbose_run chown root:$KOMPIRA_GROUP $KOMPIRA_BIN/manage.py
    verbose_run chmod 754 $KOMPIRA_BIN/manage.py
}

backup_kompira_database()
{
    if $CLUSTER_RUNNING; then return 0; fi
    if [ ! -x $KOMPIRA_BIN/manage.py ]; then
        return 0
    fi
    if [ -z "$CUR_PG_MAJVER" ]; then
        return 0
    fi
    echo_title "Backup kompira database"
    # --backup / --no-backup が指定されていない場合
    # BACKUP_MODE は INITDATA_MODE をもとにセットする (BACKUP_MODE のときはバックアップをとる)
    if [ -z "$BACKUP_MODE" ]; then
        BACKUP_MODE=$INITDATA_MODE
        echo_info "Set BACKUP_MODE=$BACKUP_MODE from INITDATA_MODE($INITDATA_MODE)"
    fi
    # --backup-process / --no-backup-process が指定されていない場合
    # BACKUP_PROCESS は INITDATA_MODE をもとにセットする (INITDATA_MODE のときはプロセスもバックアップする)
    if [ -z "$BACKUP_PROCESS" ]; then
        BACKUP_PROCESS=$INITDATA_MODE
        echo_info "Set BACKUP_PROCESS=$BACKUP_PROCESS from INITDATA_MODE($INITDATA_MODE)."
    fi
    if ! $BACKUP_MODE; then
        echo_info "BACKUP_MODE=$BACKUP_MODE (SKIP)"
        return 0;
    fi
    if [ -f $KOMPIRA_VAR_DIR/startup/do_migrate ]; then
        echo_info "Database migration not yet applied. (SKIP)"
        return 0
    fi

    # 一時的に現行バージョンの PostgreSQL を起動してバックアップを取得する
    local result=0
    local is_active_pgsql=true
    if ! is_active_service $CUR_PG_SERVICE; then
        is_active_pgsql=false
        if [ -f $CUR_PG_DATADIR/standby.signal ]; then
            verbose_run rm -f $CUR_PG_DATADIR/standby.signal.tmp
            verbose_run mv -f $CUR_PG_DATADIR/standby.signal $CUR_PG_DATADIR/standby.signal.tmp
        fi
        _service_start $CUR_PG_SERVICE
    fi
    if ! pgsql_has_kompira_table; then
        echo_info "Kompira table is not exist. (SKIP)"
    else
        BACKUP_PROCESS=$BACKUP_PROCESS verbose_run $THIS_DIR/scripts/kompira_backup.sh
        result=$?
        # INITDATA_MODE のときだけ自動リストアする
        if [ $result == 0 ] && $INITDATA_MODE; then
            verbose_run $INSTALL -g $KOMPIRA_GROUP -m 775 -d $KOMPIRA_VAR_DIR/startup
            sudo -u $KOMPIRA_USER touch $KOMPIRA_VAR_DIR/startup/do_restore
        fi
    fi
    if ! $is_active_pgsql; then
        _service_stop $CUR_PG_SERVICE
        if [ -f $CUR_PG_DATADIR/standby.signal.tmp ]; then
            verbose_run mv -f $CUR_PG_DATADIR/standby.signal.tmp $CUR_PG_DATADIR/standby.signal
        fi
    fi
    exit_if_failed "$result" "Failed to backup database"
}

restore_kompira_database()
{
    echo_info "Restore kompira database"
    if [ ! -f $KOMPIRA_BACKUP ]; then
        echo_warn "File not found: $KOMPIRA_BACKUP"
        return 0
    fi
    verbose_run $KOMPIRA_BIN/manage.py loaddata --ignorenonexistent $KOMPIRA_BACKUP
    exit_if_failed "$?" "Failed to restore database"
}

setup_pgsql()
{
    if $CLUSTER_RUNNING; then return 0; fi
    echo_title "Configure PostgreSQL settings"
    #
    # 動作中の古い postgresql を停止する
    #
    if $POSTGRESQL_MIGRATE; then
        echo_info "Disable postgresql ${CUR_PG_MAJVER}"
        _service_stop $CUR_PG_SERVICE
    fi
    #
    # PGDATA/PG_VERSION が無い場合 initdb を実施する
    # パラメータでロケールを指定する
    #
    if $POSTGRESQL_MIGRATE || [ ! -f $NEW_PG_DATADIR/PG_VERSION ]; then
        # 一度、PG_DATADIRを削除してから初期化する(initdbに失敗した残骸が残っている場合を考慮)
        verbose_run rm -rf $NEW_PG_DATADIR
        PGSETUP_INITDB_OPTIONS="--locale=$LOCALE_LANG" verbose_run $NEW_PG_BINDIR/$NEW_PG_SETUP initdb
        exit_if_failed "$?" "Failed to initialize PostgreSQL database"
    fi
    #
    # pg_upgrade を用いた PostgreSQL データベースクラスタのアップグレード
    #
    if $POSTGRESQL_UPGRADE && ! $INITDATA_MODE && [ $CUR_PG_DATADIR != $NEW_PG_DATADIR ]; then
        if $CLUSTER_CONFIGURED; then
            # 移行元クラスタがリカバリモードだと pg_upgrade できないので、一度スタンドアロンで起動する
            verbose_run rm -f $CUR_PG_DATADIR/standby.signal
            _service_start $CUR_PG_SERVICE
            sleep 1
            _service_stop $CUR_PG_SERVICE
        fi
        echo_info "Upgrade PostgreSQL $CUR_PG_MAJVER to $NEW_PG_MAJVER ($CUR_PG_DATADIR -> $NEW_PG_DATADIR)"
        verbose_run sudo -u postgres --login $NEW_PG_BINDIR/pg_upgrade --old-bindir=$CUR_PG_BINDIR --new-bindir=$NEW_PG_BINDIR --old-datadir=$CUR_PG_DATADIR --new-datadir=$NEW_PG_DATADIR
        # TODO: pg_upgrade に失敗した場合でもバックアップを用いたデータ移行の対応
        exit_if_failed "$?" "Failed to upgrade PostgreSQL database"
        # pg_upgrade に成功したら do_restore は不要
        verbose_run rm -f $KOMPIRA_VAR_DIR/startup/do_restore
        INITDATA_MODE=false
    fi

    #
    # postgresql.conf への設定追加
    #
    pgsql_conf_include_kompira $NEW_PG_DATADIR/postgresql.conf > $TMPDIR/postgresql.conf
    diff_install -o postgres -g postgres -m 0600 $TMPDIR/postgresql.conf $NEW_PG_DATADIR/postgresql.conf

    #
    # カスタム設定ディレクトリ・ファイルを作成する
    #
    verbose_run $INSTALL -o postgres -g postgres -m 0700 -d $NEW_PG_DATADIR/kompira.conf.d
    if $POSTGRESQL_MIGRATE; then
        # PostgreSQL バージョン移行時は既存設定ファイルをコピーする
        for conffile in $CUR_PG_DATADIR/kompira.conf.d/*.conf; do
            local confname=$(basename $conffile)
            diff_install -o postgres -g postgres -m 0600 $conffile $NEW_PG_DATADIR/kompira.conf.d/$confname
        done
        diff_install -o postgres -g postgres -m 0600 $CUR_PG_DATADIR/pg_hba.conf $NEW_PG_DATADIR/pg_hba.conf
        # 冗長構成の場合 setup_cluster.sh の setup_pgsql() での設定をコピーする
        if $CLUSTER_CONFIGURED; then
            verbose_run $INSTALL -o postgres -g postgres -m 700 -d "$NEW_PG_BASEDIR/pg_archive"
            pgsql_conf_include_standby $NEW_PG_DATADIR/postgresql.conf > $TMPDIR/postgresql.conf
            diff_install -o postgres -g postgres -m 0600 $TMPDIR/postgresql.conf $NEW_PG_DATADIR/postgresql.conf
            PG_MAJVER=$NEW_PG_MAJVER pgsql_convert_standby_conf $CUR_PG_BASEDIR/standby.conf > $TMPDIR/standby.conf
            diff_install -o postgres -g postgres -m 0600 $TMPDIR/standby.conf $NEW_PG_BASEDIR/standby.conf
        fi
    else
        # [MEMO] 冗長構成用の設定ファイルはここでは作成しない
        for conffile in $THIS_DIR/config/postgresql/[0-7]*.conf; do
            local confname=$(basename $conffile)
            expand_template $conffile > $TMPDIR/pgsql-$confname
            diff_install -o postgres -g postgres -m 0600 $TMPDIR/pgsql-$confname $NEW_PG_DATADIR/kompira.conf.d/$confname
        done
    fi
    #
    # ログ出力先を作成する
    #
    verbose_run $INSTALL -o postgres -g postgres -m 0750 -d $PG_LOG_DIR
    #
    # ログローテートの設定
    #
    setup_logrotate_config "postgresql"
    #
    # postgresql サービスを開始する
    #
    service_start $NEW_PG_SERVICE
    if ! $POSTGRESQL_MIGRATE; then
        # pg_hba.conf を編集して local からのアクセスを認証なしで許可する
        # 行頭が local で始まる行中の文字列 peer を trust に置換する
        verbose_run sed -e "/^local/{s/peer/trust/}" $NEW_PG_DATADIR/pg_hba.conf > $TMPDIR/pg_hba.conf
        diff_install -o postgres -g postgres -m 0600 $TMPDIR/pg_hba.conf $NEW_PG_DATADIR/pg_hba.conf
        # pg_hba.conf の変更を反映するために再起動する
        service_restart $NEW_PG_SERVICE
    fi
    #
    # INITDATA モードでは database を完全初期化する
    #
    if $INITDATA_MODE; then
        pgsql_dropdb $KOMPIRA_PG_DATABASE
        pgsql_dropuser $KOMPIRA_PG_DATABASE
    fi
    #
    # pg_upgrade した場合は vacuumdb で統計情報を更新する
    #
    if $POSTGRESQL_UPGRADE; then
        verbose_run sudo -u postgres --login LANG= $NEW_PG_BINDIR/vacuumdb --all --analyze-in-stages
    fi
    #
    # データベースユーザ $KOMPIRA_PG_USER を作成する
    #
    pgsql_create_user $KOMPIRA_PG_USER
    exit_if_failed "$?" "Failed to create PostgreSQL user '$KOMPIRA_PG_USER'"
    #
    # データベース $KOMPIRA_PG_DATABASE を作成する
    #
    pgsql_create_database $KOMPIRA_PG_DATABASE
    exit_if_failed "$?" "Failed to create PostgreSQL database '$KOMPIRA_PG_DATABASE'"
    #
    # データベースの移行に成功してから古い postgresql を無効化する
    #
    if $POSTGRESQL_MIGRATE; then
        service_disable $CUR_PG_SERVICE
    fi
    if ! $CLUSTER_CONFIGURED; then
        #
        # シングル構成のときだけ pgsql を有効化／起動したままにする
        #
        service_enable $NEW_PG_SERVICE
        if $INSTALL_ONLY; then
            service_stop $NEW_PG_SERVICE
        fi
    else
        # レプリケーションユーザ $PG_REPL_USER を作成する
        pgsql_create_repluser $PG_REPL_USER $PG_REPL_PASS
        #
        # 冗長構成のときは pgsql を停止させておく
        #
        service_stop $NEW_PG_SERVICE
        verbose_run rm -f $NEW_PG_DATADIR/standby.signal
    fi
}

setup_apache()
{
    if $CLUSTER_RUNNING; then return 0; fi
    echo_title "Configure apache settings."
    verbose_run $KOMPIRA_BIN/mod_wsgi-express install-module > $TMPDIR/mod_wsgi.conf
    exit_if_failed "$?" "Failed to install mod_wsgi"
    diff_cp $TMPDIR/mod_wsgi.conf /etc/httpd/conf.d/mod_wsgi.conf

    local httpd_conf=/etc/httpd/conf.d/kompira.conf
    local httpd_sysconf=/etc/sysconfig/httpd
    local site_packages=$($KOMPIRA_BIN/python -c "import django; print(django.__path__[0])" | sed -re 's|(.*/site-packages).*|\1|')
    local comment_if_http
    local template_prefix
    [ $HTTPS_MODE != true ] && comment_if_http="# " || comment_if_http=""
    local httpd_version=$(rpm -q httpd)
    case "$httpd_version" in
        httpd-2.4.*) template_prefix="httpd24" ;;
        *) abort_setup "Unexpected httpd version: $httpd_version" ;;
    esac

    echo_info "Append kompira configure ($template_prefix)."
    expand_template $THIS_DIR/config/httpd/$template_prefix-kompira.conf > $TMPDIR/kompira.conf
    diff_cp $TMPDIR/kompira.conf $httpd_conf

    echo_info "Change LANG setting to '$LOCALE_LANG'."
    if [ -f $httpd_sysconf ]; then
        verbose_run sed -re "s/^#?\s*(HTTPD_LANG|LANG|LC_ALL)=.*/\1=$LOCALE_LANG/" $httpd_sysconf > $TMPDIR/httpd
        if ! grep -q "^LANG=" $TMPDIR/httpd; then
            cat >> $TMPDIR/httpd <<EOF
# LANG settings
LANG=$LOCALE_LANG
EOF
        fi
        if ! grep -q "^LC_ALL=" $TMPDIR/httpd; then
            cat >> $TMPDIR/httpd <<EOF
LC_ALL=$LOCALE_LANG
EOF
        fi
    else
        # Cent/RHEL8系では、/etc/sysconfig/httpdが作成されない
        cat > $TMPDIR/httpd <<EOF
# LANG settings
LANG=$LOCALE_LANG
LC_ALL=$LOCALE_LANG
EOF
    fi
    echo_info "Change proxy settings to '$PROXY_URL'."
    if grep -E -i -q "^http?_proxy=" $TMPDIR/httpd; then
        verbose_run \
            sed -i -r \
            -e "s|^(https?_proxy)=.*|\1='$PROXY_URL'|i" \
            -e "s|^(no_proxy)=.*|\1='$NO_PROXY'|" \
            $TMPDIR/httpd
    else
        cat >> $TMPDIR/httpd <<EOF

# proxy settings
http_proxy='$PROXY_URL'
https_proxy='$PROXY_URL'
HTTP_PROXY='$PROXY_URL'
HTTPS_PROXY='$PROXY_URL'
no_proxy='$NO_PROXY'
EOF
    fi
    diff_cp $TMPDIR/httpd $httpd_sysconf

    echo_info "Append user apache to group $KOMPIRA_GROUP."
    verbose_run usermod -G $KOMPIRA_GROUP apache

    echo_info "Disable default welcome page."
    verbose_run sed -re 's/^([^#])/# \1/' /etc/httpd/conf.d/welcome.conf > $TMPDIR/welcome.conf
    diff_cp $TMPDIR/welcome.conf /etc/httpd/conf.d/welcome.conf

    echo_info "Override httpd service configue."
    cat > $TMPDIR/httpd.service <<EOF
[Service]
EnvironmentFile=/etc/sysconfig/httpd
EOF
    verbose_run mkdir -p /etc/systemd/system/httpd.service.d/
    verbose_run diff_cp $TMPDIR/httpd.service /etc/systemd/system/httpd.service.d/override.conf
    verbose_run systemctl daemon-reload

    echo_info "Override logrotate configue for httpd."
    setup_logrotate_config "httpd"

    if ! $CLUSTER_CONFIGURED; then
        #
        # シングル構成のときだけ apache を有効化／起動する
        #
        echo_info "Enable and restart apache service"
        service_enable httpd
        if $INSTALL_ONLY; then
            #
            # mod_ssl 用の TLS 鍵初期化のために httpd-init を呼び出す
            # (デーモンではないため初期化後、サービスは終了する)
            #
            # [NOTE] この処理は --install-only モードでインストールした直後に setup_cluster.sh を
            # 実行した際、httpd リソースが起動するために必要なもの。
            #
            if [ $RHEL_VERSION -ge 8 ]; then
                service_start httpd-init
            fi
        else
            service_restart httpd
        fi
    fi
}

get_available_rabbitmq_version()
{
    # 利用可能な rabbitmq-server のバージョンを取得する
    if [ ! -f $TMPDIR/available-rabbitmq-version ]; then
        echo_info "List available rabbitmq-server version (exclude those too old or too new)"
        local yum_option=$YUM_OPTION
        if $OFFLINE_MODE; then
            yum_option="$yum_option --noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
        else
            yum_option="$yum_option --disablerepo=pgdg*"
        fi
        # MEMO: centos7 の yum では --available オプションが使えないので sed で Available Packages 以下を絞り込み
        # LANG= yum --showduplicates list --available rabbitmq-server | grep ^rabbitmq-server | sed -re 's/^(\S+)\s+(\S+)(-\S*)\s+(.*)/\2/' > $TMPDIR/available-rabbitmq-version
        LANG= yum $yum_option --showduplicates list rabbitmq-server | sed -n '/^Available/,$p' | grep ^rabbitmq-server | sed -re 's/^(\S+)\s+(\S+)(-\S*)\s+(.*)/\2/' > $TMPDIR/available-rabbitmq-version
        RABBITMQ_EXCLUDED_VERSIONS=""
        RABBITMQ_AVAILABLE_VERSIONS=""
        for available_ver in $(echo $(grep -Eo '\w+\.\w+' $TMPDIR/available-rabbitmq-version | sort --version-sort | uniq)); do
            if [ $(ver2num "${available_ver}.0") -ge $(ver2num "${SUPPORTED_RMQVER_MIN}.0") ] && [ $(ver2num "${available_ver}.0") -le $(ver2num "${SUPPORTED_RMQVER_MAX}.999") ]; then
                RABBITMQ_LATEST_VERSION=${available_ver}
                RABBITMQ_AVAILABLE_VERSIONS+=" ${available_ver}"
                local available_minors=$(echo $(grep "^${available_ver}\." $TMPDIR/available-rabbitmq-version))
                echo_info "  ${available_ver}.*: $available_minors"
            else
                RABBITMQ_EXCLUDED_VERSIONS+=" ${available_ver}"
            fi
        done
        echo_info "Excluded rabbitmq-server versions: $RABBITMQ_EXCLUDED_VERSIONS"
    fi
}

get_available_postgresql_version()
{
    # 利用可能な postgresql のバージョンを取得する
    if [ ! -f $TMPDIR/available-postgresql-version ]; then
        echo_info "List available postgresql version (exclude those too old or too new)"
        local yum_option=$YUM_OPTION
        if $OFFLINE_MODE; then
            yum_option+=" --noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
        else
            local pgdg_repo
            local pgdg_repos=$(echo $(sed -n -r -e "/^\[pgdg[0-9]+\]$/s|.*\[(.*)\].*|\1|p" /etc/yum.repos.d/pgdg-redhat-all.repo))
            echo_info "postgresql repositories: $pgdg_repos"
            yum_option+=" --nogpgcheck --disablerepo=*"
            for pgdg_repo in $pgdg_repos; do
                yum_option+=" --enablerepo=${pgdg_repo}"
            done
        fi
        LANG= yum $yum_option --showduplicates list 'postgresql*-server' | grep '^postgresql.*-server' | sed -re 's/^(\S+)\s+(\S+)(-\S*)\s+(.*)/\2/' > $TMPDIR/available-postgresql-version
        POSTGRESQL_EXCLUDED_VERSIONS=""
        POSTGRESQL_AVAILABLE_VERSIONS=""
        for available_ver in $(echo $(grep -Eo '^\w+' $TMPDIR/available-postgresql-version | sort --version-sort | uniq)); do
            if [ $(ver2num "${available_ver}.0") -ge $(ver2num "${SUPPORTED_PGVER_MIN}.0") ] && [ $(ver2num "${available_ver}.0") -le $(ver2num "${SUPPORTED_PGVER_MAX}.999") ]; then
                POSTGRESQL_LATEST_VERSION=${available_ver}
                POSTGRESQL_AVAILABLE_VERSIONS+=" ${available_ver}"
                local available_minors=$(echo $(grep "^${available_ver}\." $TMPDIR/available-postgresql-version | sort --version-sort | uniq))
                echo_info "  ${available_ver}.*: $available_minors"
            else
                POSTGRESQL_EXCLUDED_VERSIONS+=" ${available_ver}"
            fi
        done
        echo_info "Excluded postgresql versions: $POSTGRESQL_EXCLUDED_VERSIONS"
    fi
}

setup_rabbitmq_conf()
{
    local rmq_conf=$1
    local conf_name=$(basename $rmq_conf)
    local conf_file="$RABBITMQ_CONFD_DIR/$conf_name"
    local temp_file="$TMPDIR/rabbitmq-$conf_name"
    echo_info "Create $conf_file"
    expand_template $rmq_conf > $temp_file
    copy_new_conf_file $temp_file $conf_file
}

setup_rabbitmq()
{
    if $CLUSTER_RUNNING; then return 0; fi
    local conf_name
    local rmq_conf
    local comment_unless_amqps
    local comment_unless_amqps_verify

    echo_title "Configure rabbitmq settings"
    if [ ! -d $RABBITMQ_CONFD_DIR ]; then
        verbose_run mkdir $RABBITMQ_CONFD_DIR
    fi
    # AMQPS モードでは rabbitmq-server を SSL 接続できるように設定する [v1.6.8]
    # rabbitmq_auth_mechanism_ssl プラグインを有効にする。
    if $AMQPS_MODE; then
        echo_info "Enable rabbitmq_auth_mechanism_ssl plugin"
        verbose_run rabbitmq-plugins enable rabbitmq_auth_mechanism_ssl
        comment_unless_amqps=""
    else
        comment_unless_amqps="# "
    fi
    # AMQPS_VERIFY モードでない場合は EXTERNAL 認証を無効にする
    # MEMO: EXTERNAL 認証を無効にすることで旧バージョンの (login_method を指定しない) kompira_sendevt でも SSL 接続が可能になる
    if $AMQPS_MODE && $AMQPS_VERIFY_MODE; then
        comment_unless_amqps_verify=""
    else
        comment_unless_amqps_verify="# "
    fi

    # アップデート時または非 AMQPS モードまたは AMQP 許可モードでは外部からの AMQP 接続を LISTEN する
    if ([ -n "$OLD_RABBITMQ_VERSION" ] && ! grep -q '^listeners.tcp' $RABBITMQ_CONFD_DIR/*.conf 2>/dev/null) || ! $AMQPS_MODE || $AMQP_ALLOWED; then
        RABBITMQ_LISTENER_TCP="0.0.0.0:5672"
    fi
    # AMQPS_VERIFY モードではクライアント側にも SSL 証明書が必須にする
    if $AMQPS_MODE && $AMQPS_VERIFY_MODE; then
        RABBITMQ_SSL_FAIL_IF_NO_PEER_CERT="true"
    fi
    # rabbitmq-server の設定ファイルを作成する [v1.6.8]
    for rmq_conf in $THIS_DIR/config/rabbitmq/{20-auth,30-tcp,30-tls}.conf; do
        setup_rabbitmq_conf $rmq_conf
    done

    # /etc/rabbitmq/rabbitmq.conf に cluster 設定がある場合は 50-cluster.conf にコピーする [v1.6.8]
    # MEMO: loopback_users=none などの設定はそのまま残す
    if [ -f /etc/rabbitmq/rabbitmq.conf ] && grep -q "^cluster_name" /etc/rabbitmq/rabbitmq.conf; then
        echo_info "Migrate cluster configuration from rabbitmq.conf to $RABBITMQ_CONFD_DIR/50-cluster.conf"
        verbose_run grep "^cluster_" /etc/rabbitmq/rabbitmq.conf > $TMPDIR/rabbitmq-50-cluster.conf
        verbose_run $INSTALL -m 0664 $TMPDIR/rabbitmq-50-cluster.conf $RABBITMQ_CONFD_DIR/50-cluster.conf
        verbose_run sed -i.bak -re '/^cluster_/d' /etc/rabbitmq/rabbitmq.conf
    fi
    # 冗長構成が設定されていれば、CIB の内容をもとに 50-cluster.conf を生成する
    if [ -f $ERLANG_COOKIE ] && [ -f $CLUSTER_CIB_FILE ]; then
        cluster_name=$(cat $ERLANG_COOKIE)
        primary_name=$(xmllint --xpath "string(//nodes/node[@id=1]/@uname)" $CLUSTER_CIB_FILE)
        secondary_name=$(xmllint --xpath "string(//nodes/node[@id=2]/@uname)" $CLUSTER_CIB_FILE)
        expand_template $THIS_DIR/config/rabbitmq/50-cluster.conf > $TMPDIR/rabbitmq-50-cluster.conf
        copy_new_conf_file $TMPDIR/rabbitmq-50-cluster.conf $RABBITMQ_CONFD_DIR/50-cluster.conf
    fi

    # Kompira 用ユーザ名とパスワードをファイルに書き出しておく [v1.6.8]
    # prestart_kompirad.sh 内部で rabbitmq-server にユーザを追加する
    (echo "KOMPIRA_AMQP_USER='$KOMPIRA_AMQP_USER'"; echo "KOMPIRA_AMQP_PASSWORD='$KOMPIRA_AMQP_PASSWORD'") > $TMPDIR/rabbitmq_kompira_user.conf
    if ! diff -q /etc/rabbitmq/kompira_user.conf $TMPDIR/rabbitmq_kompira_user.conf 2>/dev/null; then
        verbose_run $INSTALL -S .old -m 0600 $TMPDIR/rabbitmq_kompira_user.conf /etc/rabbitmq/kompira_user.conf
    fi

    # 冗長構成で rabbitmq.conf がシングル用に書き換わってしまっている場合のチェック (#1870)
    if $CLUSTER_CONFIGURED && ! grep -q "^cluster_name" /dev/null $(ls /etc/rabbitmq/rabbitmq.conf /etc/rabbitmq/conf.d/*.conf 2> /dev/null); then
        CLUSTER_CONFIG_LOST=true
    fi

    # 互換性が無い場合などデータ領域 (mnesia) は削除しておく
    if $RABBITMQ_WIPE_DATA; then
        echo_info "Wipe data area due to compatibility issues with rabbitmq-server upgrades."
        if [ -d /var/lib/rabbitmq/mnesia.old ]; then
            verbose_run rm -rf /var/lib/rabbitmq/mnesia.old
        fi
        verbose_run mv /var/lib/rabbitmq/mnesia /var/lib/rabbitmq/mnesia.old
    fi

    #
    # シングル構成のときだけ rabbitmq-server を有効化する
    #
    if ! $CLUSTER_CONFIGURED; then
        service_enable rabbitmq-server
        if ! $INSTALL_ONLY; then
            service_restart rabbitmq-server
            echo_info "Check feature flags in rabbitmq-server (new)"
            verbose_run rabbitmqctl list_feature_flags --silent | tee $TMPDIR/rabbitmq-feature_flags.new
        fi
    fi
}

setup_memcached()
{
    if $CLUSTER_RUNNING; then return 0; fi
    echo_title "Configure memcached settings"

    if ! $CLUSTER_CONFIGURED; then
        expand_template $THIS_DIR/config/systemd/memcached > $TMPDIR/memcached
        cat >> $TMPFILES_CONF_DIR/memcached.conf <<EOF
d      $MEMCACHED_SOCK_DIR 0755 $MEMCACHED_USER $MEMCACHED_GROUP -
EOF
        diff_cp $TMPDIR/memcached /etc/sysconfig/memcached
        verbose_run $INSTALL -o $MEMCACHED_USER -g $MEMCACHED_GROUP -m 0755 -d $MEMCACHED_SOCK_DIR
        service_enable memcached
        if ! $INSTALL_ONLY; then
            service_restart memcached
        fi
    fi
}

setup_postfix()
{
    if is_active_service postfix; then return 0; fi
    service_enable postfix
    if ! $INSTALL_ONLY; then
        service_restart postfix
    fi
}

setup_firewall()
{
    if $CLUSTER_RUNNING; then return 0; fi
    if is_active_service firewalld; then
        setup_firewalld $FIREWALLD_ACCEPT_PORTS
    elif is_active_service iptables; then
        setup_iptables $IPTABLES_ACCEPT_PORTS
    fi
}

setup_selinux()
{
    if $CLUSTER_RUNNING; then return 0; fi
    echo_title "Configure SELinux to $SELINUX_MODE."
    verbose_run semodule -v -i $THIS_DIR/config/selinux/kompira.pp
    verbose_run setsebool -P httpd_can_network_connect on
    verbose_run setsebool -P daemons_enable_cluster_mode on
    verbose_run setsebool -P domain_can_mmap_files on
    verbose_run setenforce $SELINUX_MODE
    verbose_run sed -e "/^SELINUX=/c SELINUX=$SELINUX_MODE" /etc/selinux/config > $TMPDIR/selinux
    diff_cp $TMPDIR/selinux /etc/selinux/config
}

setup_auditd()
{
    if $CLUSTER_RUNNING; then return 0; fi
    echo_title "Configure Auditd."
    # 冗長構成で頻出する USER_START, USER_END, CRED_DISP, CRED_ACQ のログを audit.log に記録しないようにする
    diff_cp $THIS_DIR/config/audit/kompira.rules /etc/audit/rules.d/kompira.rules
    verbose_run chmod 600 /etc/audit/rules.d/kompira.rules
    verbose_run augenrules --load
    verbose_run auditctl -l
}

setup_sysctl()
{
    echo_title "Configure sysctl settings"
    # RHEL7 系の場合に coredump を収集できるよう kernel.core_pattern を設定する (systemd-coredump が必要)
    if [ $RHEL_VERSION -lt 8 ] && [ -x /usr/lib/systemd/systemd-coredump ]; then
        diff_cp $THIS_DIR/config/sysctl/50-coredump.conf /etc/sysctl.d/50-coredump.conf
        sysctl --load /etc/sysctl.d/50-coredump.conf
    fi
}

setup_logrotate_config()
{
    # loglotate ではサフィックス .old でも設定ファイルとして読み込んでしまうので、
    # バックアップ時のサフィックスは、設定ファイルとして無視される ~ に設定する。
    local BACKUP_SUFFIX=$SIMPLE_BACKUP_SUFFIX
    export SIMPLE_BACKUP_SUFFIX="~"
    for cf in "$@"; do
        expand_template $THIS_DIR/config/logrotate/$cf > $TMPDIR/logrotate-$cf
        diff_cp $TMPDIR/logrotate-$cf /etc/logrotate.d/$cf
    done
    export SIMPLE_BACKUP_SUFFIX=$BACKUP_SUFFIX
}

setup_kompira_common()
{
    echo_title "Setup kompira common files."
    #
    # kompira グループに追加した apache アカウントで動作する httpd
    # からもログを書きこむので、パーミッションに 775 を設定する
    # 既存のログで所有者が root なものは kompira に変更する（ただし監査ログは除く）
    #
    echo_info "Create log directory: $KOMPIRA_LOG_DIR"
    verbose_run $INSTALL -g $KOMPIRA_GROUP -m 775 -d $KOMPIRA_LOG_DIR
    verbose_run restorecon -r $KOMPIRA_LOG_DIR
    verbose_run find $KOMPIRA_LOG_DIR -type f -user root ! -name "audit-*" -exec chown $KOMPIRA_USER:$KOMPIRA_GROUP {} \;

    # デフォルトの kompira.conf を生成する
    # kompira.conf がカスタマイズされている場合は上書きせず .new ファイルとしてコピーする
    echo_info "Create kompira.conf"
    expand_template $THIS_DIR/config/kompira.conf > $TMPDIR/kompira.conf
    copy_new_conf_file $TMPDIR/kompira.conf $KOMPIRA_HOME/kompira.conf -m 0644
}

setup_kompira_ssl_server()
{
    # システム起動時の kompira 環境初期化用 service を追加する [v1.6.8]
    echo_info "[systemd] Enable kompira-init service."
    expand_template $THIS_DIR/config/systemd/kompira_init.service > $TMPDIR/kompira_init.service
    verbose_run $INSTALL -m 664 $TMPDIR/kompira_init.service /usr/lib/systemd/system/kompira_init.service
    service_register kompira_init
    service_enable kompira_init

    # ssl_utils.sh で Kompira サーバ用 SSL 環境を初期化する [v1.6.8]
    KOMPIRA_SSL_DIR=$KOMPIRA_SSL_DIR verbose_run $THIS_DIR/scripts/ssl_utils.sh server-setup
}

setup_kompira_ssl_client()
{
    # ssl_utils.sh で kompira_jobmngrd, kompira_sendevt 用 SSL 環境を初期化する [v1.6.8]
    : ${SCP_REMOTEUSER:=root}
    : ${SCP_OPTIONS:=}
    if $AMQPS_MODE && $AMQPS_VERIFY_MODE && [ ! -f $KOMPIRA_SSL_DIR/certs/kompira-bundle-ca.crt ] && ! $SKIP_SCP_CERTS; then
        KOMPIRA_SSL_DIR=$KOMPIRA_SSL_DIR SCP_REMOTEUSER=$SCP_REMOTEUSER SCP_OPTIONS="$SCP_OPTIONS" verbose_run $THIS_DIR/scripts/ssl_utils.sh client-setup "$KOMPIRA_SERVER"
    fi
}

setup_kompira_jobmngr()
{
    echo_title "Setup kompira-jobmngrd."
    local comment_if_jobmngrd_mode
    [ $JOBMNGR_MODE == true ] && comment_if_jobmngrd_mode="# " || comment_if_jobmngrd_mode=""

    echo_info "[systemd] Create kompira-jobmngrd configuration file: /etc/sysconfig/kompira_jobmngrd"
    expand_template $THIS_DIR/config/systemd/kompira_jobmngrd > $TMPDIR/kompira_jobmngrd
    diff_cp $TMPDIR/kompira_jobmngrd /etc/sysconfig/kompira_jobmngrd

    echo_info "[systemd] Enable kompira-jobmngrd service."
    expand_template $THIS_DIR/config/systemd/kompira_jobmngrd.service > $TMPDIR/kompira_jobmngrd.service
    verbose_run $INSTALL -m 664 $TMPDIR/kompira_jobmngrd.service /usr/lib/systemd/system/kompira_jobmngrd.service
    service_register kompira_jobmngrd

    if ! $CLUSTER_CONFIGURED; then
        #
        # シングル構成のときだけ kompira_jobmngrd を有効化／起動する
        #
        echo_info "Start kompira-jobmngrd service."
        service_enable kompira_jobmngrd
        if ! $INSTALL_ONLY; then
            _service_restart kompira_jobmngrd
        fi
    fi
}

setup_kompira_datafiles()
{
    echo_title "Setup kompira data files."
    #
    # kompira グループに追加した apache アカウントで動作する httpd
    # からもアクセスするので、パーミッションに 775 を設定する
    #
    echo_info "Collect static files in kompira data directory."
    if $INITFILE_MODE; then
        verbose_run rm -rf $KOMPIRA_VAR_DIR/repository
    fi
    verbose_run $INSTALL -g $KOMPIRA_GROUP -m 775 -d $KOMPIRA_VAR_DIR{,/exported,/repository,/startup,/packages,/migrations}
    verbose_run find $KOMPIRA_VAR_DIR/packages -type f ! -user kompira -name "*.json" -exec chown $KOMPIRA_USER:$KOMPIRA_GROUP {} \;
    #
    # 暗号化キーファイルの作成
    #
    if ! [ -f "$DB_SECRET_KEYFILE" ]; then
        #
        # キーファイルが存在しなければ新規に作成する
        #
        echo_info "Create secret key-file: $DB_SECRET_KEYFILE"
        if [ -z "$DB_SECRET_KEY" ]; then
            local mkpasswd=$((which mkpasswd || which mkpasswd-expect) 2>/dev/null)
            DB_SECRET_KEY=$($mkpasswd -l $DB_SECRET_KEY_LEN -s 0)
        fi
        echo -n "$DB_SECRET_KEY" > "$DB_SECRET_KEYFILE"
    elif [ -n "$DB_SECRET_KEY" ]; then
        #
        # キーファイルは存在するが、secret-keyが指定されている場合、マスターキーを指定されたものに変更する
        #
        verbose_run $KOMPIRA_BIN/manage.py change_secretkey "$DB_SECRET_KEY"
    fi
    #
    # kompirad から書き込めるようにシークレットキーファイルのグループとパーミッションを変更する
    #（アップデートインストールを考慮して常に実行する）
    #
    verbose_run chgrp kompira "$DB_SECRET_KEYFILE"
    verbose_run chmod 660 "$DB_SECRET_KEYFILE"
    verbose_run restorecon "$DB_SECRET_KEYFILE"
    #
    # exported/*.dat ファイルコピー
    #
    verbose_run $INSTALL -g $KOMPIRA_GROUP -m 644 $THIS_DIR/exported/{types-*.dat,startup-*.dat,styles-*.dat,nodetypes.dat,utilities.dat} $KOMPIRA_VAR_DIR/exported
    #
    # migrations/*.py ファイルコピー
    #
    verbose_run $INSTALL -g $KOMPIRA_GROUP -m 775 $THIS_DIR/migrations/*.py $KOMPIRA_VAR_DIR/migrations
    #
    # collectstatic はシングル、マスター、スレーブいずれでも、この段階で実施する
    #
    verbose_run $KOMPIRA_BIN/manage.py collectstatic -i PACKAGES.yaml --clear --noinput
    #
    # pdf 形式のマニュアルをコピーする
    #
    local pdf locale
    for pdf in $THIS_DIR/Kompira-*.pdf; do
        local locale=${pdf%.pdf}
        locale=${locale##*-}
        if [ -n "$locale" ]; then
            if [ -d "$KOMPIRA_VAR_DIR/html/docs/$locale" ]; then
                $INSTALL -m 644 $pdf $KOMPIRA_VAR_DIR/html/docs/$locale/kompira.pdf
            else
                echo_warn "directory not found: $KOMPIRA_VAR_DIR/html/docs/$locale"
            fi
        fi
    done
    #
    # 次回 kompirad 起動時にデータベースの初期化を実施させるため、
    # $KOMPIRA_VAR_DIR/startup/ にファイルを作成しておく
    #
    sudo -u $KOMPIRA_USER touch $KOMPIRA_VAR_DIR/startup/{do_migrate,do_import_data,do_update_packages_info}
    verbose_run restorecon -r $KOMPIRA_VAR_DIR
}

setup_kompira_settings()
{
    echo_title "Setup kompira settings."
    local -x PIP=$(which pip 2> /dev/null)
    local kompira_location=$(get_kompira_location)
    local kompira_settings="$kompira_location/kompira_site/settings.py"
    if [ ! -f $kompira_settings ]; then
        echo_warn "File not found: $kompira_settings"
        return 0
    fi
    local language_code='en-us'
    case "$LOCALE_LANG" in
        ""|c.*|C.*) ;;
        ja*) language_code="ja" ;;
        *) language_code=$(echo "${LOCALE_LANG/.*/}" | tr A-Z_ a-z-) ;;
    esac
    echo_debug "language_code=$language_code (LOCALE_LANG=$LOCALE_LANG)"
    sed -re "s/^(LANGUAGE_CODE)\s+=.*/\1 = \'$language_code\'/" \
        $kompira_settings > $TMPDIR/kompira_settings.py
    diff_cp $TMPDIR/kompira_settings.py $kompira_settings
}

setup_kompira_extra_configs()
{
    echo_title "Setup kompira extra configs."
    for cf in $KOMPIRA_EXTRA_CONFIGS; do
        if ! diff -N -u $THIS_DIR/config/$cf $KOMPIRA_HOME/$cf; then
            verbose_run $INSTALL -S .old -b $THIS_DIR/config/$cf -m 644 $KOMPIRA_HOME/$cf
        fi
    done
}

setup_kompira_daemon()
{
    echo_title "Setup kompira-daemon."
    echo_info "[systemd] Create kompira-daemon configuration file: /etc/sysconfig/kompirad"
    expand_template $THIS_DIR/config/systemd/kompirad > $TMPDIR/kompirad
    diff_cp $TMPDIR/kompirad /etc/sysconfig/kompirad

    echo_info "[systemd] Enable kompira-daemon service."
    expand_template $THIS_DIR/config/systemd/kompirad.service > $TMPDIR/kompirad.service
    verbose_run $INSTALL -m 664 $TMPDIR/kompirad.service /usr/lib/systemd/system/kompirad.service
    service_register kompirad

    if ! $CLUSTER_CONFIGURED; then
        #
        # シングル構成のときだけ kompirad を有効化／起動する
        #
        echo_info "Start kompira-daemon service."
        service_enable kompirad
        if ! $INSTALL_ONLY; then
            _service_restart kompirad
        fi
    fi
}

setup_kompira_default()
{
    setup_kompira_datafiles
    setup_kompira_settings
    setup_kompira_extra_configs
    verbose_run restorecon -r $KOMPIRA_HOME
    setup_logrotate_config "kompira_audit"
    setup_kompira_daemon
}

update_cluster()
{
    #
    # アップデート時にクラスタの設定変更が必要な場合はここに実装
    #
    if ! $CLUSTER_CONFIGURED; then return 0; fi
    echo_title "Update clustering settings."

    #
    # kompira をアップデートすると /usr/lib/systemd/system/kompira*.service を更新するが、
    # 冗長構成では Requires 設定を除外して /etc/systemd/system に配置する
    #
    local svcname
    for svcname in kompirad.service kompira_jobmngrd.service; do
        verbose_run sed -re "s/^\s*(Requires\s*=.*)/# \1/" /usr/lib/systemd/system/$svcname > $TMPDIR/cluster-$svcname
        diff_cp $TMPDIR/cluster-$svcname /etc/systemd/system/$svcname
    done
    verbose_run $SYSTEMCTL daemon-reload

    #
    # rsyncd サービスが enabled の場合は disable にする
    #
    if is_enabled_service rsyncd; then
        verbose_run systemctl stop rsyncd
        verbose_run systemctl disable rsyncd
    fi

    #
    # リソースエージェントに改善パッチをあてる
    #
    patch_resource_agents

    #
    # V1.6.6 以降で kompirad 起動前に pcs property を操作するための権限が必要なため
    # kompira ユーザを haclient に追加
    #
    setup_ha_user

    #
    # V1.6.6 以降では、kompirad の後で httpd を起動する必要があるため
    # res_httpd を後(vipの前)に移動する
    # pcs を起動しなくても CIB ファイルの操作で設定更新を行なう [v1.6.8]
    #
    verbose_run pcs -f $CLUSTER_CIB_FILE cluster cib $TMPDIR/cib-org.xml
    verbose_run cp $TMPDIR/cib-org.xml $TMPDIR/cib-new.xml
    local found_kompirad=false
    local found_httpd=false
    local before_vip=""
    local replace_httpd=false
    local webgroups=$(pcs -f $TMPDIR/cib-new.xml resource group list | grep webserver:)
    local cib_push=false
    for res in ${webgroups#webserver:}; do
        case $res in
            "res_httpd")
                found_httpd=true
                ;;
            "res_kompirad")
                found_kompirad=true
                ;;
            "res_vip")
                # VIPリソースがあれば、その前に移動する
                before_vip="--before res_vip"
                ;;
        esac
        if $found_httpd && ! $found_kompirad; then
            # 先に httpd が見つかった場合は res_httpd の順序を入れ替える
            replace_httpd=true
        fi
    done
    if $replace_httpd; then
        echo_info "Replace res_httpd after res_kompirad"
        verbose_run pcs -f $TMPDIR/cib-new.xml resource group remove webserver res_httpd
        verbose_run pcs -f $TMPDIR/cib-new.xml resource group add webserver res_httpd $before_vip
        cib_push=true
    fi
    if $POSTGRESQL_MIGRATE; then
        # PostgreSQL バージョン移行時は res_pgsql の設定 (bindir/pgdata) を更新する
        echo_info "Update res_pgsql configs (from $CUR_PG_SERVICE to $NEW_PG_SERVICE)"
        verbose_run pcs -f $TMPDIR/cib-new.xml resource update res_pgsql bindir="$NEW_PG_BINDIR" pgdata="$NEW_PG_DATADIR"
        # sync_master.sh で既にリカバリモードで動作できているという誤認識を防止するため master-res_pgsql をクリアしておく
        local nodes=$(xmllint --xpath "//nodes/node/@uname" $TMPDIR/cib-new.xml 2>/dev/null | sed -re 's/\s*uname="([^"]+)"/\1 /g')
        for node in $nodes; do
            verbose_run pcs -f $TMPDIR/cib-new.xml node attribute $node master-res_pgsql=
        done
        cib_push=true
    fi
    if $cib_push; then
        echo_info "Push the updated CIB XML"
        verbose_run pcs -f $CLUSTER_CIB_FILE cluster cib-push $TMPDIR/cib-new.xml
    fi

    #
    # 以下の場合を除いて pcs を自動起動する
    # - --skip-cluster-start が指定されている場合
    # - rabbitmq-server のクラスタ設定が失われている場合 (#1870)
    # - バージョン互換性などのために Full Stop アップグレードが必要と判断した場合
    #
    if $SKIP_CLUSTER_START || $CLUSTER_CONFIG_LOST || $CLUSTER_FULLSTOP_UPGRADE; then return 0; fi
    echo_info "Kompira cluster is starting..."
    verbose_run pcs cluster start
    cluster_wait_current_dc
    wait_resources_stabilize
    exit_if_failed $? "Resources were not stable."
}

test_kompira()
{
    if $CLUSTER_CONFIGURED || $INSTALL_ONLY; then return 0; fi
    echo_title "Test access to kompira."
    local result=$(curl -Lksf $KOMPIRA_TEST_URL -w '%{http_code}' -o $TMPDIR/test-kompira.out)
    if [ $result != 200 ]; then
        cat $TMPDIR/test-kompira.out
        abort_setup "Access Failed!"
    fi
    echo_info "Access succeeded: $(grep "brand-version" $TMPDIR/test-kompira.out)"
}

install_kompira_sendevt()
{
    install_requires_sendevt
    if $REQUIRES_ONLY; then return 0; fi
    install_package_sendevt
    setup_kompira_ssl_client
    setup_kompira_common
}

install_kompira_jobmngr()
{
    install_requires_jobmngrd
    if $REQUIRES_ONLY; then return 0; fi
    install_package_jobmngr
    setup_sysctl
    setup_kompira_ssl_client
    setup_kompira_common
    setup_kompira_jobmngr
}

install_kompira_default()
{
    install_requires_kompira
    if $REQUIRES_ONLY; then return 0; fi
    install_package_default
    check_installed_versions
    setup_kompira_ssl_server
    setup_pgsql
    setup_apache
    setup_rabbitmq
    setup_firewall
    setup_selinux
    setup_auditd
    setup_sysctl
    setup_memcached    # SELinuxをpermissiveにした後で実行する必要がある
    setup_postfix
    setup_kompira_common
    setup_kompira_jobmngr
    setup_kompira_default
    update_cluster
}

install_kompira()
{
    if $SENDEVT_MODE; then
        install_kompira_sendevt
    elif $JOBMNGR_MODE; then
        install_kompira_jobmngr
    else
        install_kompira_default
    fi
}

final_check()
{
    # インストール後の最終チェック
    if $AMQPS_MODE && $AMQPS_VERIFY_MODE; then
        if [ ! -f $KOMPIRA_SSL_DIR/certs/kompira-bundle-ca.crt ]; then
            # AMQPS モードで SSL 証明書を生成またはコピーしていない場合の警告 [v1.6.8]
            if ( $JOBMNGR_MODE || $SENDEVT_MODE ) then
                echo_warn ""
                echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                echo_warn ""
                echo_warn "For SSL connection, copy the SSL certificate from the Kompira server"
                echo_warn "to $KOMPIRA_SSL_DIR/certs by any means."
                echo_warn "Simply run the script ssl_utils.sh."
                echo_warn ""
                echo_warn "  # /opt/kompira/bin/ssl_utils.sh client-setup $KOMPIRA_SERVER"
                echo_warn ""
                echo_warn "Or copy the SSL certificate file manually from the Kompira server."
                echo_warn ""
                echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                echo_warn ""
            else
                echo_warn ""
                echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                echo_warn ""
                echo_warn "For SSL connection, create the CA certificate and SSL certificates."
                echo_warn "Simply run the script ssl_utils.sh."
                echo_warn ""
                echo_warn "  # /opt/kompira/bin/ssl_utils.sh server-setup"
                echo_warn ""
                echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                echo_warn ""
            fi
        elif $CLUSTER_CONFIGURED && [ $(grep "# $KOMPIRA_SSL_DIR/ca-source" $KOMPIRA_SSL_DIR/certs/kompira-bundle-ca.crt | wc -l) -lt 2 ]; then
            # 冗長構成で相互の CA 証明書がバンドルされていない場合
            echo_info ""
            echo_info "--------------------------------------------------------------------------"
            echo_info ""
            echo_info "For mutual AMQPS connections in a clustered environment,"
            echo_info "copy and bundle CA certificates from the opposing Kompira server."
            echo_info "Simply run the script ssl_utils.sh."
            echo_info ""
            echo_info "  # /opt/kompira/bin/ssl_utils.sh get-other-ca"
            echo_info ""
            echo_info "--------------------------------------------------------------------------"
            echo_info ""
        fi
    fi

    # rabbitmq-server のマイナーバージョンが上がった場合は feature flags を有効化するようにメッセージ
    # データ領域 (mnesia) を削除する場面では不要
    if $RABBITMQ_UPGRADED && ! $RABBITMQ_WIPE_DATA; then
        echo_info ""
        echo_info "--------------------------------------------------------------------------"
        echo_info ""
        echo_info "RabbitMQ is upgraded: $OLD_RABBITMQ_VERSION -> $NEW_RABBITMQ_VERSION"
        echo_info ""
        echo_info "After rabbitmq-server has started, check the feature flags with the following command."
        echo_info ""
        echo_info "    # rabbitmqctl list_feature_flags"
        echo_info ""
        echo_info "If there are any feature flags that are not enabled, "
        echo_info "enable all feature flags with the following command after the upgrade is complete."
        echo_info ""
        echo_info "    # rabbitmqctl enable_feature_flag all"
        echo_info ""
        echo_info "--------------------------------------------------------------------------"
        echo_info ""
    fi

    # より新しいバージョンの rabbitmq-server が利用可能な場合のメッセージ
    if $RABBITMQ_AVAILABLE_NEWER; then
        echo_info ""
        echo_info "--------------------------------------------------------------------------"
        echo_info ""
        echo_info "A newer rabbitmq-server is available."
        echo_info "    current version: $NEW_RABBITMQ_VERSION"
        echo_info "    available versions: $RABBITMQ_AVAILABLE_VERSIONS"
        echo_info ""
        echo_info "Please consider updating to every 1 minor version."
        echo_info ""
        echo_info "--------------------------------------------------------------------------"
        echo_info ""
    fi

    # 冗長構成で rabbitmq.conf がシングル用に書き換わってしまっている場合の警告 (#1870)
    if $CLUSTER_CONFIGURED && $CLUSTER_CONFIG_LOST; then
        echo_warn ""
        echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo_warn ""
        echo_warn "CORRUPT CONFIG DETECTED! (/etc/rabbitmq)"
        echo_warn ""
        echo_warn "YOU CAN RESTART THE CLUSTER AS IS."
        echo_warn "HOWEVER THE FOLLOWING MEASURES ARE RECOMMENDED."
        echo_warn ""
        echo_warn "Sorry, please stop both clusters and redo cluster_setup.sh on each nodes."
        echo_warn ""
        echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo_warn ""
    fi

    # 冗長構成で両系停止アップグレードが必要で pcs 自動起動していない場合の警告
    if $CLUSTER_CONFIGURED && $CLUSTER_FULLSTOP_UPGRADE; then
        echo_warn ""
        echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo_warn ""
        echo_warn "FULL STOP UPGRADES ARE REQUIRED! (For version compatibility)"
        echo_warn ""
        if [ "$CUR_PG_VERSION" != "$NEW_PG_VERSION" ]; then
            echo_warn "  postgresql: $CUR_PG_VERSION -> $NEW_PG_VERSION"
        fi
        if [ "$OLD_ERLANG_VERSION" != "$NEW_ERLANG_VERSION" ] || [ "$OLD_RABBITMQ_VERSION" != "$NEW_RABBITMQ_VERSION" ]; then
            echo_warn "  erlang: $OLD_ERLANG_VERSION -> $NEW_ERLANG_VERSION"
            echo_warn "  rabbitmq-server: $OLD_RABBITMQ_VERSION -> $NEW_RABBITMQ_VERSION"
        fi
        echo_warn ""
        echo_warn " - Automatic cluster start was skipped."
        echo_warn " - Please stop both systems and upgrade each one."
        if [ "$CUR_PG_MAJVER" == "$NEW_PG_MAJVER" ]; then
            echo_warn " - Then start the clusters in order with the following command."
            echo_warn ""
            echo_warn "     # pcs cluster start"
            echo_warn ""
            echo_warn " - At that time, start the cluster first on the node that was active before the upgrade."
            echo_warn ""
        else
            echo_warn " - First, start the cluster with the following command on the node that was active before the upgrade."
            echo_warn ""
            echo_warn "     # pcs cluster start"
            echo_warn ""
            echo_warn " - Next, start the cluster with the following command on the node that was standby before the upgrade."
            echo_warn ""
            echo_warn "     # /opt/kompira/bin/sync_master.sh --force"
            echo_warn ""
        fi
        echo_warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo_warn ""
    fi
}

create_extra()
{
    local requirements=$THIS_DIR/requirements/kompira.txt
    local repotrack_options
    local available_ver
    if [ ! -f $requirements ]; then
        abort_setup "requirements file not found!"
    fi
    eval $(grep -E "^(PACKAGES_FOR_HA|RA_PAF_PKGURL)" $THIS_DIR/setup_cluster.sh)

    # Prepare to download python3 packages for extra package.
    verbose_run $THIS_DIR/scripts/python_utils.sh --prepare-only --dry-run download all > $TMPDIR/download-python3.sh
    source $TMPDIR/download-python3.sh
    PACKAGES_FOR_OFFLINE="$PACKAGES_FOR_OFFLINE $PYTHON_PACKAGES"
    if [ -n "$PYTHON_REQUIRE_REPOS" ]; then
        for repo in $PYTHON_REQUIRE_REPOS; do
            verbose_run yum-config-manager --enable "$repo" > /dev/null
        done
    fi
    if [ -n "$PYTHON_DEBUGINFO_PACKAGES" ]; then
        DEBUGINFO="$DEBUGINFO $PYTHON_DEBUGINFO_PACKAGES"
    fi

    if [ $RHEL_VERSION == 7 ]; then
        repotrack_options="-p $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM"
        # AWS RHEL 7 の場合、repotrack にパッチをあてる必要がある
        # https://access.redhat.com/solutions/5299581
        if [ $SYSTEM == "RHEL" ] && [ -f /etc/yum/pluginconf.d/amazon-id.conf ] && grep -Fq 'init_plugins=False' /usr/bin/repotrack; then
            verbose_run sed -i.orig 's/my.doConfigSetup(fn=opts.config,init_plugins=False)/my.doConfigSetup(fn=opts.config)/g' /usr/bin/repotrack
        fi
    elif [ $RHEL_VERSION -ge 8 ]; then
        case $SYSTEM_RELEASEVER in
            8.[0-4]|8.[0-4].*)
                # RHEL 8.4 以下では modulemd-tools をインストールするのに Copr repository が必要
                # https://github.com/rpm-software-management/modulemd-tools
                verbose_run dnf -y copr enable frostyx/modulemd-tools-epel
                ;;
        esac
        if [ $RHEL_VERSION -ge 9 ]; then
            PACKAGES_FOR_OFFLINE="$PACKAGES_FOR_OFFLINE memcached-selinux audit sssd-* libsss_*"
        fi
        PACKAGES_FOR_INSTALL="$PACKAGES_FOR_INSTALL yum python3-librepo rpm-plugin-*"
        repotrack_options="--destdir $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM --alldeps --resolve"
    fi

    # パッケージリポジトリのセットアップ
    setup_package_repository

    # mod-wsgiをコンパイルするために必要
    PACKAGES_FOR_KOMPIRA="$PACKAGES_FOR_KOMPIRA redhat-rpm-config"
    if $EXTRA_WITH_HA; then
        if [ $SYSTEM == "RHEL" ]; then
            # RHEL の HighAvailability パッケージ用リポジトリを有効化する
            verbose_run yum-config-manager --enable "$HA_REPONAME_RHEL" > /dev/null
        elif [ -n "$HA_REPONAME_OTHERS" ]; then
            # 上記以外の OS 向けに HighAvailability パッケージ用リポジトリを有効化する
            verbose_run yum-config-manager --enable "$HA_REPONAME_OTHERS" > /dev/null
        fi
    else
        PACKAGES_FOR_HA=
    fi

    # 利用可能な rabbitmq-server の各マイナーバージョンを extra パッケージに含める
    get_available_rabbitmq_version
    local packages_for_kompira_rabbitmq
    for available_ver in $RABBITMQ_AVAILABLE_VERSIONS; do
        packages_for_kompira_rabbitmq+=" rabbitmq-server-${available_ver}.*"
    done

    # 利用可能な postgresql の各バージョンを extra パッケージに含める
    # TODO: Amazon 環境での対応
    local packages_for_kompira_postgresql
    if [ "$SYSTEM" == "AMZN" ]; then
        packages_for_kompira_postgresql+=" ${NEW_PG_PREFIX}-server ${NEW_PG_PREFIX}-contrib"
    else
        get_available_postgresql_version
        for available_ver in $POSTGRESQL_AVAILABLE_VERSIONS; do
            local pg_prefix="postgresql${available_ver}"
            packages_for_kompira_postgresql+=" ${pg_prefix}-server-${available_ver}.* ${pg_prefix}-contrib-${available_ver}.*"
            verbose_run yum-config-manager --enable "pgdg${available_ver}" > /dev/null
        done
    fi

    echo_title "Create extra package"
    verbose_run mkdir -p $KOMPIRA_EXTRA_DIR/{/etc/yum.repos.d,$KOMPIRA_EXTRA_PIP,$KOMPIRA_EXTRA_RPM}

    echo_info "Install rpm packages for create extra package"
    yum_install $PACKAGES_FOR_EXTRA $PACKAGES_FOR_MODULES $PACKAGES_FOR_BUILD $PACKAGES_FOR_SENDEVT_BUILD $PACKAGES_FOR_JOBMNGR_BUILD $PACKAGES_FOR_KOMPIRA_BUILD

    echo_info "Download rpm packages"
    verbose_run repotrack $repotrack_options \
                $PACKAGES_FOR_INSTALL $PACKAGES_FOR_OFFLINE $PACKAGES_FOR_UPDATE \
                $PACKAGES_FOR_SENDEVT $PACKAGES_FOR_SENDEVT_BUILD \
                $PACKAGES_FOR_JOBMNGR $PACKAGES_FOR_JOBMNGR_BUILD \
                $PACKAGES_FOR_KOMPIRA $PACKAGES_FOR_KOMPIRA_BUILD \
                $packages_for_kompira_rabbitmq \
                $packages_for_kompira_postgresql \
                $PACKAGES_FOR_SELINUX \
                $PACKAGES_FOR_SETUP_CLUSTER $PACKAGES_FOR_HA $WITH_RPM
    exit_if_failed "$?" "Failed to download rpm packages"
    # OS によっては repotrack gdb に失敗する（成功した場合だけ extra パッケージに含める）
    verbose_run repotrack $repotrack_options $PACKAGES_FOR_GDB
    # Amazon Linux 2 の場合、resource-agents-paf がレポジトリに含まれていないため、直接ダウンロードする
    if [ $SYSTEM == "AMZN" ] && $EXTRA_WITH_HA; then
        verbose_run curl -LO --output-dir $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM $RA_PAF_PKGURL
    fi
    if [ -n "$DEBUGINFO" ]; then
        echo_info "Download debuginfo packages"
        local debuginfo_options="-y --nogpgcheck"
        if [ -n "$PYTHON_DEBUGINFO_REPOS" ]; then
            for repo in $PYTHON_DEBUGINFO_REPOS; do
                debuginfo_options+=" --enablerepo=$repo"
            done
        fi
        if [ $SYSTEM != "AMZN" ]; then
            debuginfo_options+=" --disablerepo=pgdg* --enablerepo=pgdg$NEW_PG_MAJVER"
        fi
        verbose_run debuginfo-install $debuginfo_options --downloadonly --downloaddir=$KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM $DEBUGINFO
        exit_if_failed "$?" "Failed to download debuginfo packages"
    fi
    createrepo $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM
    # RHEL 8 系以降ではリポジトリに modules 情報を加える
    if [ $RHEL_VERSION -ge 8 ]; then
        verbose_run createrepo_c $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM
        verbose_run repo2module -s stable $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM modules.yaml
        verbose_run modifyrepo_c --mdtype=modules modules.yaml $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_RPM/repodata/
    fi
    cat > $KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_REPO <<EOF
[$KOMPIRA_EXTRA_NAME]
name=$KOMPIRA_EXTRA_NAME
baseurl=file://$KOMPIRA_EXTRA_RPM
gpgcheck=0
enabled=0
EOF

    # 各バージョンの python で wheelhouse をビルドする
    local python_path
    for python_path in $(./scripts/python_utils.sh which all); do
        if [ -x $python_path ]; then
            echo_info "Download wheel packages ($(basename $python_path))"
            local py_version_nodot=$(get_python_version_nodot $python_path)
            local pyenv_name=".local-py${py_version_nodot}"
            local wheelhouse_name="wheelhouse-py${py_version_nodot}"
            local wheelhouse_dir="$KOMPIRA_EXTRA_DIR/$KOMPIRA_EXTRA_BASE/$wheelhouse_name"
            verbose_run $python_path -m venv $pyenv_name
            verbose_run $pyenv_name/bin/pip install -U pip wheel setuptools
            verbose_run mkdir -p $wheelhouse_dir
            verbose_run $pyenv_name/bin/pip wheel -w $wheelhouse_dir \
                        -r $requirements \
                        "pip" "wheel" \
                        $REQUIREMENTS_FOR_OFFLINE $WITH_WHL
            exit_if_failed "$?" "Failed to create wheelhouse (py${py_version_nodot})"
        fi
    done

    echo_info "Packaging extra package"
    verbose_run tar zcvf $KOMPIRA_EXTRA_DIR.tar.gz -C $KOMPIRA_EXTRA_DIR etc opt
}

usage_exit()
{
    cat <<EOF
Usage: $(basename $0) [OPTIONS] <kompira-server>

  --force                       Force install.
  --https                       Configure apache to force secure access (default).
  --no-https                    Configure apache to enable unsecure access.
  --amqps                       Configure rabbitmq-server to force secure access (default).
  --amqps-verify                Configure rabbitmq-server to force secure access with certificate verification.
  --no-amqps                    Configure rabbitmq-server to disable secure access.
  --allow-insecure-amqp         Configure rabbitmq-server to allow insecure access from outside.
  --initdata                    Initialize kompira database.
  --initfile                    Initialize $KOMPIRA_VAR_DIR/{repository}.
  --secret-key <secret-key>     Secret key for encrypted fields of DB.
  --backup                      Backup the database before updating.
  --no-backup                   Skip database backup.
  --backup-process              Include process objects in the backup.
  --no-backup-process           Exclude process objects in the backup.
  --rhui                        Install in RHUI mode.
  --rhel-option-repo <repo>     Specify RHEL repository.
  --skip-python3-install        Skip python3 installation.
  --skip-cluster-start          Skip cluster start.
  --skip-scp-certs              Skip copying the SSL certificates from the kompira server.
  --skip-rabbitmq-update        Skip updating rabbitmq-server.
  --skip-postgresql-update      Skip updating postgresql.
  --rabbitmq-version <ver>      Specify rabbitmq-server version (e.g.: 3.10.*).
  --postgresql-version <ver>    Specify postgresql-version (e.g.: 16).
  --locale-lang <lang>          Configure system locale laguage.
  --locale-timezone <zonename>  Configure system locale timezone.
  --proxy <proxy>               Specify a proxy in the form
                                [user:passwd@]proxy.server:port.
  --temp-proxy <proxy>          Proxy settings applied only during installation.
  --noproxy <hosts>             Comma-separated list of hosts which do not use proxy.
  --temp-noproxy <hosts>        No proxy settings applied only during installation.
  --jobmngr                     Install Kompira job manager package.
  --sendevt                     Install Kompira send event package.
  --with-rpm <rpms>             Install with additional rpm packages.
  --with-whl <wheels>           Install with additional wheel packages.
  --with-gdb                    Install with gdb and debuginfo.
  --offline                     Install in offline mode using the kompira-extra package.
  --extra                       Create the Kompira kompira-extra package for offline install.
  --extra-without-ha            Create the Kompira kompira-extra package without the HA packages.
  --install-only                Installation only, each daemon is not started.
  --dry-run                     Check the parameters without actually installing.
  --help                        Show this message.

EOF
    exit 1
}

parse_options()
{
    SPECIFY_SERVER=false
    OPTIONS=`getopt -q -o '' -l https,no-https,amqps,amqps-verify,no-amqps,allow-insecure-amqp,force,initdata,initfile,secret-key:,backup,no-backup,backup-process,no-backup-process,update,rhui,rhel-option-repo:,skip-python3-install,skip-cluster-start,skip-scp-certs,skip-rabbitmq-update,skip-postgresql-update,rabbitmq-version:,postgresql-version:,locale-lang:,locale-timezone:,temp-proxy:,temp-noproxy:,proxy:,noproxy:,jobmngr,sendevt,requires-only,with-rpm:,with-whl:,with-gdb,offline,extra,extra-without-ha,install-only,dry-run,help -- "$@"`
    [ $? != 0 ] && usage_exit
    eval set -- "$OPTIONS"
    while true
    do
        arg="$1"
        case "$arg" in
            --https) HTTPS_MODE=true ;;
            --no-https) HTTPS_MODE=false ;;
            --amqps) AMQPS_MODE=true ;;
            --amqps-verify) AMQPS_MODE=true; AMQPS_VERIFY_MODE=true ;;
            --no-amqps) AMQPS_MODE=false; AMQPS_VERIFY_MODE=false ;;
            --allow-insecure-amqp) AMQP_ALLOWED=true ;;
            --force) FORCE_MODE=true ;;
            --initdata) INITDATA_MODE=true ;;
            --initfile) INITFILE_MODE=true ;;
            --secret-key) DB_SECRET_KEY=$2; shift ;;
            --backup) BACKUP_MODE=true ;;
            --no-backup) BACKUP_MODE=false ;;
            --backup-process) BACKUP_PROCESS=true ;;
            --no-backup-process) BACKUP_PROCESS=false ;;
            --rhui) RHUI_MODE=true ;;
            --rhel-option-repo) OPTION_REPONAME=$2; shift ;;
            --skip-python3-install) SKIP_PYTHON3_INSTALL=true ;;
            --skip-cluster-start) SKIP_CLUSTER_START=true ;;
            --skip-scp-certs) SKIP_SCP_CERTS=true ;;
            --skip-rabbitmq-update) SKIP_RABBITMQ_UPDATE=true ;;
            --skip-postgresql-update) SKIP_POSTGRESQL_UPDATE=true ;;
            --rabbitmq-version) RABBITMQ_SPEC_VERSION=$2; shift ;;
            --postgresql-version) POSTGRESQL_SPEC_VERSION=$2; shift ;;
            --locale-lang) CONFIG_LOCALE_LANG=true; LOCALE_LANG=$2; shift ;;
            --locale-timezone) CONFIG_LOCALE_TIMEZONE=true; LOCALE_TIMEZONE=$2; shift ;;
            --temp-proxy) TEMP_PROXY_URL=$(normalize_proxy_url $2); shift;;
            --temp-noproxy) TEMP_NO_PROXY=$2; shift ;;
            --proxy) PROXY_URL=$(normalize_proxy_url $2); TEMP_PROXY_URL=$PROXY_URL; shift ;;
            --noproxy) NO_PROXY=$2; TEMP_NO_PROXY=$NO_PROXY; shift ;;
            --jobmngr) JOBMNGR_MODE=true; SPECIFY_SERVER=true ;;
            --sendevt) SENDEVT_MODE=true; SPECIFY_SERVER=true ;;
            --requires-only) REQUIRES_ONLY=true ;;
            --with-rpm) WITH_RPM=$2; shift ;;
            --with-whl) WITH_WHL=$2; shift ;;
            --with-gdb) WITH_GDB=true ;;
            --offline) OFFLINE_MODE=true; SETUP_TYPE="$SETUP_TYPE (offline-mode)" ;;
            --extra) EXTRA_MODE=true; SETUP_TYPE="$SETUP_TYPE (extra-mode)" ;;
            --extra-without-ha) EXTRA_MODE=true; EXTRA_WITH_HA=false; SETUP_TYPE="$SETUP_TYPE (extra-mode w/o HA)" ;;
            --install-only) INSTALL_ONLY=true ;;
            --dry-run) DRY_RUN=true ;;
            --update)
                echo "option $arg is deprecated."
                ;;
            --) shift; break ;; # 引数は無視
            *) usage_exit ;;
        esac
        shift
    done

    if [ -n "$PYTHON_VERSION" ]; then
        if [ -f $KOMPIRA_BIN/python ]; then
            local installed_python_version=$(get_python_version $KOMPIRA_BIN/python)
            echo "You specified the Python version ($PYTHON_VERSION),"
            echo "but the Kompira environment containing python $installed_python_version is already set up in $KOMPIRA_BIN."
            echo "The Python version can only be specified during a clean install."
            exit 1
        fi
        local valid_python_version=false
        case $PYTHON_VERSION in
            [0-9].+([0-9]))
                if [ $(ver2num $PYTHON_VERSION) -ge $(ver2num $SUPPORTED_PYVER_MIN) ] &&
                   [ $(ver2num $PYTHON_VERSION) -le $(ver2num $SUPPORTED_PYVER_MAX) ]; then
                   valid_python_version=true
                fi ;;
            *) ;;
        esac
        if ! $valid_python_version; then
            echo "Your specified Python version $PYTHON_VERSION is invalid."
            echo "The Python version must be in the format X.Y and must be between $SUPPORTED_PYVER_MIN and $SUPPORTED_PYVER_MAX."
            exit 1
        fi
        local kompira_wheel_file=$(get_kompira_wheel_file $KOMPIRA_WHLFILE_DEFAULT ${PYTHON_VERSION/./})
        if [ ! -f $kompira_wheel_file ]; then
            local kompira_wheel_pyvers=$(echo $(find $(dirname $KOMPIRA_WHLFILE_DEFAULT) -name $(basename "${KOMPIRA_WHLFILE_DEFAULT/py3-none-any/py*-none-any}") -printf "%f\n" | sed -re 's/.*py([0-9])([0-9]*)-none-any.whl/\1.\2/'))
            echo "Sorry, this package does not contain wheel files for Python $PYTHON_VERSION."
            echo "Available Python versions containing the Kompira wheel package file: $kompira_wheel_pyvers"
            exit 1
        fi
    fi

    if $JOBMNGR_MODE && $SENDEVT_MODE; then
        echo '--jobmngr and --sendevt options are exclusive.'
        echo
        exit 1
    fi

    if $SPECIFY_SERVER; then
        if [ -z "$1" ]; then
            echo 'must specify <kompira-server>'
            echo
            usage_exit
        fi
        KOMPIRA_SERVER="$1"
    else
        if [ -n "$1" ]; then
            echo "unknown argument \"$1\""
            echo
            usage_exit
        fi
    fi

    # 非 AMQPS_VERIFY モードおよび AMQP アクセス許可モードでは KOMPIRA_AMQP_PASSWORD にユーザ名を指定する (INSECURE!)
    if [ -z "$KOMPIRA_AMQP_PASSWORD" ] && ( ! $AMQPS_MODE || ! $AMQPS_VERIFY_MODE || $AMQP_ALLOWED ); then
        KOMPIRA_AMQP_PASSWORD="$KOMPIRA_AMQP_USER"
    fi

    if [ -n "$DB_SECRET_KEY" ] && [ ${#DB_SECRET_KEY} -lt "$DB_SECRET_KEY_MIN_LEN" ]; then
        echo "A secret key should be at least $DB_SECRET_KEY_MIN_LEN characters"
        echo
        exit 1
    fi
}

################################################################

set -o pipefail
parse_options "$@"
exec > >(tee $INSTALL_LOG) 2>&1
create_tmpdir
init_variables
start_setup

#
# 環境チェック
#
check_root
check_environ
check_cluster
check_python
check_update
check_license
if $DRY_RUN; then
    exit_setup
fi
install_requires_prepare
yum_clean

#
# extra パッケージの作成
#
if $EXTRA_MODE; then
    create_extra
    exit_setup
fi

#
# システム設定
#
check_locale_lang
configure_locale_lang
configure_locale_timezone

#
# kompira アカウント/ホームディレクトリを作成する
#
create_user
create_home

#
# データベースのバックアップ
#
backup_kompira_database

#
# 動作中の kompira を停止し、アンインストールする
#
stop_kompira
uninstall_kompira
uninstall_packages

#
# virtualenv で仮想環境を作成する
#
create_virtualenv

#
# virtualenv 環境をアクティブにしてインストールを実施する
#
activate_virtualenv
install_kompira
deactivate_virtualenv

# オフラインインストールで利用した extra パッケージのモジュールは無効化しておく
if $OFFLINE_MODE; then
    disable_kompira_extra_module
fi

# インストールした Kompira に HTTP アクセスできるか確認する
if ! $JOBMNGR_MODE && ! $SENDEVT_MODE; then
    test_kompira
fi
final_check
exit_setup
