#
# Copyright (c) 2012-2014 Fixpoint Inc. All rights reserved.
# ---
#
#   セットアッププログラム用共通関数定義
#
#
shopt -s extglob
#
# バージョン情報はパッケージングの際に置換される(Makefile参照)
#
BRANCH=1.6
VERSION=1.6.11
SHORT_VERSION=1.6.11


trap "interrupt" SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

REQUIRES_ARCH="x86_64"
REQUIRES_SYSTEM_CENT="CentOS*release [789]*"
REQUIRES_SYSTEM_AMZN2="Amazon Linux release 2 *"
REQUIRES_SYSTEM_AMZN2023="Amazon Linux release 2023.*"
REQUIRES_SYSTEM_RHEL="Red Hat Enterprise Linux* release [789].*"
REQUIRES_SYSTEM_ROCKY="Rocky Linux release [89].*"
REQUIRES_SYSTEM_ALMA="AlmaLinux release [89].*"
REQUIRES_SYSTEM_MIRACLE="MIRACLE LINUX release [89].*"

SUPPORTED_PYVER_MIN=3.6
SUPPORTED_PYVER_MAX=3.9

SUPPORTED_RMQVER_MIN=3.8
SUPPORTED_RMQVER_MAX=3.12

DEPRECATED_PGVER=12
SUPPORTED_PGVER_MIN=12
SUPPORTED_PGVER_MAX=17
LATEST_PGVER_AMZN2=14
LATEST_PGVER_AMZN2023=16
LATEST_PGVER_RHEL7=15
LATEST_PGVER_DEFAULT=17

#
# システム種別チェック
#
: ${SYSTEM_NAME:=}
: ${SYSTEM_RELEASE:=}
: ${RHEL_CLONE:=false}
: ${RHEL_VERSION:=$(rpm -E '%{rhel}' 2>/dev/null)}
if [ -z "$SYSTEM_RELEASE" ]; then
    for file in /etc/system-release /etc/redhat-release; do
        if [ -f $file ]; then SYSTEM_RELEASE=$(< $file); break; fi
    done
fi
case $SYSTEM_RELEASE in
    $REQUIRES_SYSTEM_CENT) SYSTEM="CENT"; SYSTEM_NAME="cent$RHEL_VERSION" ;;
    $REQUIRES_SYSTEM_RHEL) SYSTEM="RHEL"; SYSTEM_NAME="rhel$RHEL_VERSION" ;;
    $REQUIRES_SYSTEM_AMZN2) SYSTEM="AMZN"; SYSTEM_NAME="amzn2" ;;
    $REQUIRES_SYSTEM_AMZN2023) SYSTEM="AMZN"; RHEL_VERSION=9; SYSTEM_NAME="amzn2023" ;;
    $REQUIRES_SYSTEM_ROCKY) SYSTEM="ROCKY"; SYSTEM_NAME="rocky$RHEL_VERSION"; RHEL_CLONE=true ;;
    $REQUIRES_SYSTEM_ALMA) SYSTEM="ALMA"; SYSTEM_NAME="alma$RHEL_VERSION"; RHEL_CLONE=true ;;
    $REQUIRES_SYSTEM_MIRACLE) SYSTEM="MIRACLE"; SYSTEM_NAME="miracle$RHEL_VERSION"; RHEL_CLONE=true ;;
    *)                     SYSTEM="unknown" ;;
esac
if [ -z "$SYSTEM_RELEASEVER" ]; then
    SYSTEM_RELEASEVER=$(echo "$SYSTEM_RELEASE" | sed -r -e "s/.*release ([0-9.]+).*/\1/")
fi

#
# [RHEL] RHUI チェック
#
if [ -z "$RHUI_MODE" ]; then
    if [ $SYSTEM == "RHEL" ] && grep -qiE "^\[rhui\b.*\]" /etc/yum.repos.d/*.repo; then
        RHUI_MODE=true
    else
        RHUI_MODE=false
    fi
fi

#
# postgres レポジトリ／パッケージ情報
#
PG_YUMREPO="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${RHEL_VERSION}-${REQUIRES_ARCH}/pgdg-redhat-repo-latest.noarch.rpm"

#
# High-Availability リポジトリ情報
#
case $SYSTEM in
RHEL)
    # RHEL7以前とRHEL8以後で HA パッケージ用リポジトリ名が異なる
    # https://access.redhat.com/ja/solutions/6174152
    if [ $RHEL_VERSION -le 7 ]; then
        if $RHUI_MODE; then
            HA_REPONAME_RHEL="rhel-ha-for-rhel-${RHEL_VERSION}-server-rhui-rpms"
        else
            HA_REPONAME_RHEL="rhel-ha-for-rhel-${RHEL_VERSION}-server-rpms"
        fi
    else
        if $RHUI_MODE; then
            HA_REPONAME_RHEL="rhel-${RHEL_VERSION}-for-${REQUIRES_ARCH}-highavailability-rhui-rpms"
        else
            HA_REPONAME_RHEL="rhel-${RHEL_VERSION}-for-${REQUIRES_ARCH}-highavailability-rpms"
        fi
    fi
    ;;
CENT|ROCKY|ALMA)
    # クローン OS での HA パッケージ用リポジトリ名はバージョンによって異なる
    #   >= 9.0: highavailability
    #   >= 8.3: ha
    #    < 8.2: HighAvailability
    # ただし 8.2 以前は "HighAvailability" で、8.3 以降は "ha" に名称変更している
    case $SYSTEM_RELEASEVER in
        9|9.*) HA_REPONAME_OTHERS="highavailability" ;;
        8.[0-2].*) HA_REPONAME_OTHERS="HighAvailability" ;;
        *) HA_REPONAME_OTHERS="ha" ;;
    esac
    ;;
MIRACLE)
    # MIRABLE Linux は独自のリポジトリ名で提供される
    HA_REPONAME_OTHERS="$RHEL_VERSION-latest-HighAvailability"
    ;;
esac

#
# systemd 判別チェック
#
if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
    SYSTEMD=true
else
    SYSTEMD=false
fi
SHOW_OPTIONS="SYSTEM SYSTEM_NAME SYSTEM_RELEASE SYSTEM_RELEASEVER PLATFORM_PYTHON PYTHON SYSTEMD TMPDIR"
: ${PLATFORM_PYTHON:=$((which /usr/libexec/platform-python || which /usr/bin/python3 || which python) 2>/dev/null)}
: ${PYTHON:=$((which /opt/kompira/bin/python || which python3.9 || which python3.8 || which python3.7 || which python3.6 || which python3) 2>/dev/null)}
: ${PIP:=$(which pip 2>/dev/null)}
: ${SERVICE:=service}
: ${SYSTEMCTL:=systemctl}
: ${INSTALL:=install}
: ${SUBSCRIPTION_MANAGER:=$(which subscription-manager 2>/dev/null)}
: ${NETWORK_SCRIPTS_DIR:=/etc/sysconfig/network-scripts}
: ${TMPDIR_TEMPLATE:=".tmp.install-$(date +%Y%m%d-%H%M).XXXX"}
: ${TMPDIR:="/tmp"}
: ${TMPFILES_CONF_DIR:="/usr/lib/tmpfiles.d"}
: ${SETUP_TYPE:="Setup"}
: ${SKIP_CLEAN_YUM_CACHE:=true}
: ${SKIP_CHECK_FREESPACE:=false}
: ${OFFLINE_MODE:=false}

#
# runuser/su チェック
#
if [ -z "$SU" ]; then
    if [ -x /sbin/runuser ]; then
        SU=/sbin/runuser
    else
        SU=su
    fi
fi

#
# variables for Kompira
#
: ${KOMPIRA_USER:=kompira}
: ${KOMPIRA_GROUP:=kompira}
: ${KOMPIRA_HOME:=/opt/kompira}
: ${KOMPIRA_VAR_DIR:=/var/opt/kompira}
: ${KOMPIRA_LOG_DIR:=/var/log/kompira}
: ${KOMPIRA_BACKUP:="$KOMPIRA_VAR_DIR/kompira_backup.json.gz"}
: ${KOMPIRA_ENV:="$KOMPIRA_HOME"}
: ${KOMPIRA_BIN:="$KOMPIRA_HOME/bin"}
: ${KOMPIRA_SSL_DIR:="$KOMPIRA_HOME/ssl"}
: ${KOMPIRA_PG_USER:=kompira}
: ${KOMPIRA_PG_DATABASE:=kompira}
: ${KOMPIRA_AMQP_USER:=kompira}
: ${KOMPIRA_AMQP_PASSWORD:=}
: ${KOMPIRA_REALM_NAME:=default}
: ${KOMPIRA_HA_CLIENT:=haclient}

#
# variables for extra package
#
: ${KOMPIRA_EXTRA_NAME:="kompira-extra-$SHORT_VERSION.$SYSTEM_NAME"}
: ${KOMPIRA_EXTRA_DIR:="$KOMPIRA_EXTRA_NAME"}
: ${KOMPIRA_EXTRA_REPO:="/etc/yum.repos.d/$KOMPIRA_EXTRA_NAME.repo"}
: ${KOMPIRA_EXTRA_BASE:="/opt/kompira/extra/$SHORT_VERSION/$SYSTEM_NAME"}
: ${KOMPIRA_EXTRA_PIP:="$KOMPIRA_EXTRA_BASE/pip"}
: ${KOMPIRA_EXTRA_RPM:="$KOMPIRA_EXTRA_BASE/packages"}

#
# variables for proxy settings
#
: ${PROXY_URL:="$http_proxy"}
: ${NO_PROXY:="${no_proxy:-localhost,127.0.0.1}"}
if id $KOMPIRA_USER > /dev/null 2>&1; then
    if [ "OK" == "$($SU - $KOMPIRA_USER -c "echo OK" 2>/dev/null)" ]; then
        PROXY_URL=$($SU - $KOMPIRA_USER -c "echo \$http_proxy")
        NO_PROXY=$($SU - $KOMPIRA_USER -c "echo \$no_proxy")
    fi
fi

#
# variables for cluster
#
CLUSTER_CIB_FILE="/var/lib/pacemaker/cib/cib.xml"
CLUSTER_RUNNING=false
CLUSTER_MASTER=false
if [ -e $CLUSTER_CIB_FILE ]; then
    CLUSTER_CONFIGURED=true
else
    CLUSTER_CONFIGURED=false
fi

#
# 現在の PostgreSQL の構成をチェックする
#
: ${CUR_PG_BINDIR:=}
: ${CUR_PG_DATADIR:=}
if [ -n "$CUR_PG_BINDIR" ] && [ -n "$CUR_PG_DATADIR" ]; then
    :
elif $CLUSTER_CONFIGURED; then
    # pacemaker に設定されている res_pgsql の bindir/pgdata を取得する
    CUR_PG_BINDIR=$(xmllint --xpath "string(//instance_attributes[@id='res_pgsql-instance_attributes']/nvpair[@name='bindir']/@value)" $CLUSTER_CIB_FILE)
    CUR_PG_DATADIR=$(xmllint --xpath "string(//instance_attributes[@id='res_pgsql-instance_attributes']/nvpair[@name='pgdata']/@value)" $CLUSTER_CIB_FILE)
else
    # systemctl で有効になっている postgres サービスから bindir/pgdata を取得する
    CUR_PG_SERVICE=$(LANG= $SYSTEMCTL list-unit-files -t service --no-legend "postgresql*" 2>/dev/null | grep enabled | head -1 | cut -d' ' -f1 | sed -re 's/\.service//')
    if [ -n "$CUR_PG_SERVICE" ]; then
        CUR_PG_DATADIR=$($SYSTEMCTL cat $CUR_PG_SERVICE | grep '^Environment=PGDATA=' | sed -re 's/Environment=PGDATA=//')
        CUR_PG_EXECSTART=$($SYSTEMCTL cat $CUR_PG_SERVICE | grep '^ExecStart=' | sed -re 's/ExecStart=//' | cut -d' ' -f1)
        if [ -n "$CUR_PG_EXECSTART" ]; then
            CUR_PG_BINDIR=$(dirname $(readlink -f $CUR_PG_EXECSTART))
        fi
    fi
fi
# 末尾に / があれば除去しておく
CUR_PG_BINDIR=${CUR_PG_BINDIR%/}
CUR_PG_DATADIR=${CUR_PG_DATADIR%/}
#
# CUR_PG_BINDIR から現在の PostgreSQL のバージョンを取得
#
if [ -n "$CUR_PG_BINDIR" ]; then
    CUR_PSQL=$CUR_PG_BINDIR/psql
    CUR_POSTGRES=$CUR_PG_BINDIR/postgres
    if ! [ -x $CUR_PSQL ] || ! [ -x $CUR_POSTGRES ]; then
        echo "ERROR: CUR_PSQL($CUR_PSQL) and/or CUR_POSTGRES($CUR_POSTGRES) are not executable!" > /dev/stderr
        exit 1
    fi
    CUR_PG_VERSION=$($CUR_POSTGRES --version | sed -re 's|.* ([0-9.]+).*|\1|')
    if ! [[ "${CUR_PG_VERSION}" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: INVALID POSTGRESQL VERSION ($CUR_PG_VERSION) DETECTED!" > /dev/stderr
        exit 1
    elif [ ${CUR_PG_VERSION/.*/} -lt 10 ]; then
        # postgresql-9.x 以下の場合 -> postgresql-9x
        CUR_PG_MAJVER="${CUR_PG_VERSION/./}"
    else
        # postgresql-10.x 以上の場合 -> postgresql-10
        CUR_PG_MAJVER="${CUR_PG_VERSION/.*/}"
    fi
    if [ -z "$CUR_PG_MAJVER" ]; then
        echo "ERROR: CUR_PG_MAJVER could not be confirmed!" > /dev/stderr
        exit 1
    fi
    if [ -z "$CUR_PG_SERVICE" ]; then
        if [ "$SYSTEM" == "AMZN" ]; then
            CUR_PG_SERVICE="postgresql"
        else
            CUR_PG_SERVICE="postgresql-$CUR_PG_MAJVER"
        fi
    fi
fi
if [ -n "$CUR_PG_DATADIR" ]; then
    CUR_PG_BASEDIR=$(dirname $CUR_PG_DATADIR)
fi

#
# variables for postgres
#
PG_LOG_DIR="/var/log/postgresql"
PG_REPL_USER="repl"
PG_REPL_PASS=$PG_REPL_USER
PGSQL_USER="postgres"
PGSQL_DB="postgres"
DB_SECRET_KEYFILE="$KOMPIRA_VAR_DIR/.secret_key"

#
# variables for rabbitmq-server
#
RABBITMQ_CONFD_DIR="/etc/rabbitmq/conf.d"
RABBITMQ_USER="rabbitmq"
RABBITMQ_GROUP="rabbitmq"
RABBITMQ_LISTENER_TCP="127.0.0.1:5672"
RABBITMQ_LISTENER_SSL="0.0.0.0:5671"
RABBITMQ_SSL_VERIFY="verify_peer"
RABBITMQ_SSL_FAIL_IF_NO_PEER_CERT="false"
ERLANG_COOKIE="/var/lib/rabbitmq/.erlang.cookie"


#
# variables for memcached
#
MEMCACHED_USER="memcached"
MEMCACHED_GROUP="memcached"
MEMCACHED_SOCK_DIR="/var/run/memcached"

#
# 冗長構成の対向ホスト名
#
HA_LOCALHOST=ha-kompira-local
HA_OTHERHOST=ha-kompira-other
: ${HA_LOCALNAME:=}
: ${HA_OTHERNAME:=}

#
# 冗長構成のリソース属性値
#
PGSQL_MASTER_SCORE=1001
PGSQL_SLAVE_SCORE=1000

: ${ECHO_LEVEL:=3}
ECHO_OPTIONS=
ECHO_PREFIX=
ECHO_POSTFIX=

# cp/install コマンドでのデフォルトバックアップ接尾辞
export SIMPLE_BACKUP_SUFFIX=.old

_now()
{
    date "+%F %T"
}

_echo()
{
    local msg
    for msg in "$@"; do
        echo $ECHO_OPTIONS "[$(_now)] ${ECHO_PREFIX}${msg}${ECHO_POSTFIX}"
    done
}

echo_debug()
{
    ECHO_PREFIX="DEBUG: " _echo "$@"
}
echo_verbose()
{
    ECHO_PREFIX="VERBOSE: " _echo "$@"
}
echo_info()
{
    ECHO_PREFIX="INFO: " _echo "$@"
}
echo_warn()
{
    ECHO_PREFIX="WARN: " _echo "$@"
}
echo_error()
{
    ECHO_PREFIX="ERROR: " _echo "$@"
}
echo_always()
{
    ECHO_PREFIX="****: " _echo "$@"
}
echo_param()
{
    echo_info "$(printf "    %-24s = %s" "$1" "$2")"
}
echo_title()
{
    echo_always "----------------------------------------------------------------" "$@" ""
}

verbose_run()
{
    echo_verbose "run: $*" >&2
    "$@"
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        echo_verbose "status=$rc" >&2
    fi
    return $rc
}

#
# [BUG] templateの末尾に改行コードが無いと展開したファイルに__EOF__が付加されてしまう
#
expand_template()
{
    eval "$(echo "cat <<__EOF__"; cat $1; echo "__EOF__")"
}

diff_install()
{
    diff_and_cmd $INSTALL "$@"
}

diff_cp()
{
    diff_and_cmd cp -b "$@"
}

diff_and_cmd()
{
    local old=${!#}
    set ${@:1:$#-1}
    local new=${!#}
    set ${@:1:$#-1}
    if ! diff -N -u "$old" "$new"; then
        verbose_run "$@" "$new" "$old"
    fi
}

copy_new_conf_file()
{
    local temp_file=$1
    local conf_file=$2
    shift 2
    local install_opts=$@
    if [ -z "$install_opts" ]; then
        install_opts="-m 0664"
    fi
    if [ ! -f $conf_file ]; then
        # 設定ファイルが存在しない場合はそのままコピーする
        verbose_run $INSTALL $install_opts $temp_file $conf_file
    elif ! diff -q $conf_file $temp_file; then
        # 設定ファイルがカスタマイズされている場合は上書きせず .new ファイルとしてコピーする
        verbose_run $INSTALL $install_opts $temp_file $conf_file.new
        echo_info "Copied $conf_file.new (check the difference)"
        verbose_run diff -u $conf_file $conf_file.new
    fi
}

interrupt()
{
    echo_title "Abort ${SETUP_TYPE}."
    exit 1
}

inquire()
{
    echo -n "$1 "
    if [ -t 0 ]; then
        read answer
        case $answer in
            [yY]* ) answer="y";;
            [nN]* ) answer="n";;
            *) answer="$2" ;;
        esac
    else
        answer="$2"
        abort_setup "stdin is not the terminal!"
    fi
}

is_runnable()
{
    test -x "$(which $1 2>/dev/null)"
}

is_yum_installed()
{
    local pkg
    local yum_option=$YUM_OPTION
    if $OFFLINE_MODE; then
        yum_option="$yum_option --noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
    fi
    for pkg; do
        if ! yum $yum_option list installed $pkg > /dev/null 2>&1
        then
            return 1
        fi
    done
}

exit_if_failed()
{
    local rc=$1
    shift
    if [ $rc -ne 0 ]; then
        abort_setup "$@"
    fi
}

yum_localinstall()
{
    if [ -n "$*" ]; then
        local DESCRIPTION="${DESCRIPTION:-$@}"
        local yum_option=$YUM_OPTION
        echo_info "Local install $DESCRIPTION"
        verbose_run yum -y --noplugins --disablerepo=* $yum_option localinstall "$@"
        exit_if_failed "$?" "Failed to install $DESCRIPTION"
    fi
}

yum_install()
{
    if [ -n "$*" ]; then
        local DESCRIPTION="${DESCRIPTION:-$@}"
        local yum_option=$YUM_OPTION
        echo_info "Install $DESCRIPTION"
        if $OFFLINE_MODE; then
            yum_option="--noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME $yum_option"
        fi
        verbose_run yum -y $yum_option install "$@"
        exit_if_failed "$?" "Failed to install $DESCRIPTION"
    fi
}

set_state_kompira_extra_module()
{
    local state=$1
    if [ -d /opt/kompira/extra ] && [ $RHEL_VERSION == 8 ]; then
        # kompira_extra モジュールを有効化または無効化する
        # MEMO: yum module disable コマンドはオフライン時に時間がかかるため /etc/dnf の設定ファイルを直接書き換える
        echo_info "Set state kompira extra module (state=$state)"
        verbose_run find /etc/dnf/modules.d/ -name "kompira*.module" -exec sed -i -r -e "s/^state=.*/state=$state/" {} \;
    fi
}

enable_kompira_extra_module()
{
    set_state_kompira_extra_module "enabled"
}

disable_kompira_extra_module()
{
    set_state_kompira_extra_module "disabled"
}

debuginfo_install()
{
    if [ -n "$*" ]; then
        local DESCRIPTION="${DESCRIPTION:-$@}"
        local yum_option=$YUM_OPTION
        echo_info "Debuginfo-install $DESCRIPTION"
        if $OFFLINE_MODE; then
            yum_option="$yum_option --noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
        elif [ "$SYSTEM" != "AMZN" ]; then
            yum_option="$yum_option --disablerepo=pgdg*"
        fi
        #
        # 前の yum がロックを掴んでいるケースがあるため待機する
        #
        sleep 1  # 直後は yum.pid が生成されないため最初に少し待機する
        for i in $(seq 10); do
            if [ ! -f /var/run/yum.pid ]; then
                break
            fi
            echo_info "Waiting yum lock released ..."
            sleep 5
        done
        verbose_run debuginfo-install $yum_option -y "$@"
        exit_if_failed "$?" "Failed to debuginfo-install $DESCRIPTION"
    fi
}

remove_if_installed()
{
    local pkg
    for pkg; do
        if is_yum_installed $pkg; then
            echo_info "Remove ${pkg}"
            verbose_run yum $YUM_OPTION -y remove $pkg
        fi
    done
}

ver2num()
{
    echo $1 | awk -F. '{printf "%03d%03d%03d%03d\n",$1,$2,$3,$4}'
}

# Function: get_locale_info
# Description: It retrieves the current {locale value} by key
# Parameters: 
#   $1: {locale key}: string, default: LC_CTYPE
# Return: value of {locale key}: string
get_locale_info()
{
    local key="${1:-LC_CTYPE}"
    (eval "$(locale); echo \$$key") 2>/dev/null 
}

get_rpm_version()
{
    local name=$1
    rpm -q "$name" --info | sed -rne 's/^Version\s*:\s*(\S+).*/\1/p'
}

get_pip_info()
{
    local name=$1
    local field=$2
    $PIP show "$name" 2> /dev/null | sed -rne "s/^$field:\s*(.*)/\1/p"
}

get_kompira_version()
{
    get_pip_info "Kompira" "Version"
}

get_kompira_location()
{
    get_pip_info "Kompira" "Location"
}

get_object_version() {
    $KOMPIRA_BIN/manage.py shell <<EOF
from kompira.models.version import get_object_version
print("{0:04}".format(get_object_version() or 0))
EOF
}

set_object_version() {
    local current=$1
    $KOMPIRA_BIN/manage.py shell <<EOF
from kompira.models.version import set_object_version
set_object_version('$current')
EOF
}

pip_uninstall_if_installed()
{
    local pkg
    for pkg; do
        if $PIP show $pkg > /dev/null; then
            echo_info "Uninstall ${pkg} [$PIP]"
            verbose_run $PIP uninstall -y $pkg
        fi
    done
}

is_active_service()
{
    local svc=$1
    $SYSTEMCTL is-active $svc > /dev/null 2>&1
}

is_enabled_service()
{
    local svc=$1
    $SYSTEMCTL is-enabled $svc > /dev/null 2>&1
}

_service_status()
{
    local svc=$1
    verbose_run $SYSTEMCTL status $svc
}

_service_start()
{
    local svc=$1
    verbose_run $SYSTEMCTL start $svc
}

_service_stop()
{
    local svc=$1
    verbose_run $SYSTEMCTL stop $svc
}

_service_restart()
{
    local svc=$1
    verbose_run $SYSTEMCTL restart $svc
}

service_start()
{
    local svc=$1
    echo_info "Start service: ${svc}"
    _service_start $svc
    exit_if_failed "$?" "Failed to start ${svc}"
}

service_stop()
{
    local svc=$1
    if is_active_service $svc; then
        echo_info "Stop service: ${svc}"
        _service_stop $svc
        exit_if_failed "$?" "Failed to stop ${svc}"
    fi
}

service_restart()
{
    local svc=$1
    if is_active_service $svc; then
        echo_info "Restart service: ${svc}"
        _service_restart $svc
        exit_if_failed "$?" "Failed to restart ${svc}"
    else
        service_start $svc
    fi
}

service_register()
{
    local svc=$1
    verbose_run $SYSTEMCTL daemon-reload
}

service_enable()
{
    local svc=$1
    verbose_run $SYSTEMCTL enable $svc.service
}

service_disable()
{
    local svc=$1
    verbose_run $SYSTEMCTL disable $svc.service
}

check_root()
{
    if [ $(whoami) != root ]; then
        abort_setup "Please execute as root user."
    fi
}

check_arch()
{
    local arch=$(uname -i)
    case $arch in
        $REQUIRES_ARCH)
            echo_info "Confirmed architecture: $arch" ;;
        *)
            abort_setup "Please execute on the x86_64 Linux." ;;
    esac
}

check_system()
{
    if [ -z "$SYSTEM_NAME" ]; then
        abort_setup "This is not a supported OS!"
    fi
    if [ ! "SYSTEMD" ]; then
        abort_setup "Systemd is not found!"
    fi
    echo_info "Confirmed system: $SYSTEM_RELEASE"
}

get_cluster_status()
{
    if [ ! -e $CLUSTER_CIB_FILE ]; then
        echo_info "Pacemaker is not configured."
        return 0
    fi
    CLUSTER_CONFIGURED=true
    PCS_VERSION=$(get_rpm_version pcs)
    if ! is_active_service "pacemaker"; then
        echo_info "Pacemaker is stop."
        return 0
    fi
    CLUSTER_RUNNING=true
    if pgsql_is_primary; then
        echo_info "Pacemaker is running (MASTER)"
        CLUSTER_MASTER=true
    else
        echo_info "Pacemaker is running (SLAVE)"
        CLUSTER_MASTER=false
    fi
}

check_subscription()
{
    local offline_mode=${1:-false}
    if $offline_mode || $RHUI_MODE; then
        return 0
    fi
    if [[ $SYSTEM == "RHEL" && -n "$SUBSCRIPTION_MANAGER" ]]; then
        echo_info "[RHEL] Check subscription status"
        if ! $SUBSCRIPTION_MANAGER status; then
            abort_setup "Please attach a valid subscription." \
                        "" \
                        "ex) subscription-manager register --auto-attach"
        fi
    fi
}

check_freespace()
{
    # ディスク空き容量チェック
    local destdir=$1
    local datadir=$2
    local require_freespace_rate=$3
    local df_destdir=0
    local du_datadir=$(LANG= du -sk $datadir | tail -1 | cut -f1)
    while true; do
        df_destdir=$(echo $(LANG= df -k $destdir 2>/dev/null | tail -1) | cut -d' ' -f4)
        if [ -n "$df_destdir" ] || [ $destdir == "/" ]; then
            break
        fi
        destdir=$(dirname $destdir)
    done
    if [ -z "$df_destdir" ]; then
        return
    fi
    echo_info "$(printf "Data used: %'13d KiB (%s)" $du_datadir "$datadir")"
    echo_info "$(printf "Free space:%'13d KiB (%s)" $df_destdir "$destdir")"
    if [ $du_datadir -gt 0 ] && [ -n "$require_freespace_rate" ]; then
        local current_freespace_rate=$(echo $df_destdir $du_datadir | awk '{printf("%.2f",100*$1/$2)}')
        local result_freespace=$(echo $current_freespace_rate $require_freespace_rate | awk '{print($1>=$2?"OK":"NG")}')
        echo_info "Free space rate: $current_freespace_rate% ($result_freespace)"
        if ! $SKIP_CHECK_FREESPACE && [ "$result_freespace" != "OK" ]; then
            # データサイズに対して $require_freespace_rate パーセント以上の空き容量がなければエラーとする
            abort_setup "Not enough free space. ($require_freespace_rate% free space required for data used)"
        fi
    fi
}

update_rpm_gpg_key()
{
    if [ "$SYSTEM" == "ALMA" ]; then
        # ALMA Linux 8 の GPG KEY を更新する
        # https://almalinux.org/blog/2023-12-20-almalinux-8-key-update/
        echo_info "Update AlmaLinux 8 PGP key"
        verbose_run rpm -q gpg-pubkey-ced7258b-6525146f
        if [ $? -ne 0 ]; then
            verbose_run rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
        fi
    fi
}

install_pgdg_redhat_repo()
{
    echo_info "Install Yum repositories (PGSQL)"
    rm -f /etc/yum.repos.d/pgdg-redhat-all.repo.rpmnew
    yum_localinstall $PG_YUMREPO
    exit_if_failed "$?" "Failed to install repository: $PG_YUMREPO"
    # アップデートされた場合は pgdg-redhat-all.repo.rpmnew を pgdg-redhat-all.repo に置き換える
    if [ -f /etc/yum.repos.d/pgdg-redhat-all.repo.rpmnew ]; then
        rm -f /etc/yum.repos.d/pgdg-redhat-all.repo.rpmold
        verbose_run mv /etc/yum.repos.d/pgdg-redhat-all.repo /etc/yum.repos.d/pgdg-redhat-all.repo.rpmold
        verbose_run mv /etc/yum.repos.d/pgdg-redhat-all.repo.rpmnew /etc/yum.repos.d/pgdg-redhat-all.repo
    fi
}

pgsql_replica()
{
    local master_host=$1
    local save_datadir=$2
    if [ -z "$save_datadir" ]; then
        save_datadir=true
    fi
    verbose_run rm -f $CUR_PG_BASEDIR/tmp/PGSQL.lock
    # TODO: --no-backup オプションで $CUR_PG_DATADIR.old へ退避せず削除する
    if $save_datadir; then
        verbose_run rm -rf $CUR_PG_DATADIR.old
        verbose_run mv -f $CUR_PG_DATADIR $CUR_PG_DATADIR.old
    else
        verbose_run rm -rf $CUR_PG_DATADIR
    fi
    # pg_baseback コマンドでプライマリ機のデータベースクラスタをコピーする
    verbose_run sudo -u postgres --login $CUR_PG_BINDIR/pg_basebackup -h $master_host -U $PG_REPL_USER -D $CUR_PG_DATADIR -X stream --checkpoint=fast -P
    local rc=$?
    if $save_datadir; then
        if [ $rc -eq 0 ]; then
            # 成功した場合は $CUR_PG_DATADIR.old を削除する
            echo_info "Backup succeed: cleanup $CUR_PG_DATADIR.old"
            verbose_run rm -rf $CUR_PG_DATADIR.old
        else
            # 失敗した場合は $CUR_PG_DATADIR.old を元に戻す
            echo_error "Backup FAILED!: restore $CUR_PG_DATADIR"
            verbose_run rm -rf $CUR_PG_DATADIR
            verbose_run mv -f $CUR_PG_DATADIR.old $CUR_PG_DATADIR
        fi
    fi
    return $rc
}

pgsql_conf_include_standby()
{
    local src_postgresql_conf=$1
    cat $src_postgresql_conf
    if ! grep -F -q "include '../standby.conf" $src_postgresql_conf; then
        cat <<EOF

# include replication settings
include '../standby.conf'
EOF
    fi
}

pgsql_conf_include_kompira()
{
    local src_postgresql_conf=$1
    cat $src_postgresql_conf
    if ! grep -F -q "kompira.conf.d" $src_postgresql_conf; then
        cat <<EOF

# include kompira custom settings
include_dir 'kompira.conf.d'
EOF
    fi
}

pgsql_convert_standby_conf()
{
    local src_standby_conf=$1
    # PostgreSQL 12 で wal_keep_segments が DEPRECATED になり、PostgreSQL 13 以降では wal_keep_size で設定する必要がある。
    # wal_segment_size を 16MB と仮定して wal_keep_segments と wal_keep_size を変換する。
    if [ $PG_MAJVER -ge 13 ]; then
        verbose_run sed -r -e 's|^(\s*)wal_keep_segments(\s*=\s*)([0-9]+).*|echo "\1wal_keep_size\2$((\3*16))"|eg' $src_standby_conf
    else
        verbose_run sed -r -e 's|^(\s*)wal_keep_size(\s*=\s*)([0-9]+).*|echo "\1wal_keep_segments\2$((\3/16))"|eg' $src_standby_conf
    fi
}

pgsql_dropuser()
{
    local pg_user=$1
    echo_info "Delete postgresql user: $pg_user"
    verbose_run dropuser -U $PGSQL_USER --if-exists -e "$pg_user"
}

pgsql_dropdb()
{
    local pg_database=$1
    echo_info "Delete postgresql database: $pg_database"
    verbose_run dropdb -U $PGSQL_USER --if-exists -e "$pg_database"
}

pgsql_create_user()
{
    local pg_user=$1
    if ! psql -U "$pg_user" -d $PGSQL_DB -c \\q 2>/dev/null; then
        echo_info "Create postgresql user: $pg_user"
        verbose_run createuser -U $PGSQL_USER --createdb -e "$pg_user"
    else
        echo_debug "The postgres user '$pg_user' already exists."
    fi
}

pgsql_create_repluser()
{
    local pg_user=$1
    local pg_pass=$2
    if ! psql -U "$pg_user" -d $PGSQL_DB -c \\q 2>/dev/null; then
        echo_info "Create postgresql replication user: $pg_user"
        verbose_run psql -U $PGSQL_USER -c "create user $pg_user password '$pg_pass' NOSUPERUSER REPLICATION"
    else
        echo_debug "The postgres replication user '$pg_user' already exists."
    fi
}

pgsql_create_database()
{
    local pg_database=$1
    if ! psql -U $PGSQL_USER -d "$pg_database" -c \\q 2>/dev/null; then
        echo_info "Create postgresql database: $pg_database"
        verbose_run createdb -U $KOMPIRA_PG_USER --encoding=utf8 -e "$pg_database"
    else
        echo_debug "The postgres database '$pg_database' already exists."
    fi
}

pgsql_has_kompira_table()
{
    # postgres が初期化されているか（kompira データベースにテーブルが存在するか）確認する
    LANG= psql -U kompira -Atc '\dt' kompira | grep -q "table"
}

pgsql_is_in_recovery()
{
    # postgres がリカバリモードか確認する
    psql -U $PGSQL_USER -Atc "select pg_is_in_recovery()" 2>/dev/null
}

pgsql_is_primary()
{
    local pg_is_in_recovery rc
    pg_is_in_recovery=$(pgsql_is_in_recovery)
    rc=$?
    if [ $rc -ne 0 ]; then
        echo_warn "PostgreSQL is stop (rc=$rc)"
        return 2
    fi
    case $pg_is_in_recovery in
        f)
            echo_info "PostgreSQL is running as a primary."
            return 0
            ;;
        t)
            echo_info "PostgreSQL is running as a hot standby."
            return 1
            ;;
        *)
            abort_setup "Invalid result: pg_is_in_recovery=$pg_is_in_recovery"
            ;;
    esac
}

setup_firewalld()
{
    echo_title "Configure firewalld settings."
    local rule rule_elem rule_spec prot port
    for rule; do
        case $rule in
            +([0-9])/@(tcp|udp))
                verbose_run firewall-cmd --add-port=$rule --permanent
                ;;
            +([0-9]|\.)?(/+([0-9])))
                verbose_run firewall-cmd --zone=trusted --add-source=$rule --permanent
                ;;
            *)
                verbose_run firewall-cmd --add-service=$rule --permanent
                ;;
        esac
    done
    verbose_run firewall-cmd --reload
}

setup_iptables()
{
    echo_title "Configure iptables settings."
    local rule rule_elem rule_spec prot port
    iptables-save > $TMPDIR/iptables_cur
    for rule; do
        rule_spec=""
        for rule_elem in ${rule/,/ }; do
            case $rule_elem in
                +([0-9])/@(tcp|udp))
                    prot=${rule_elem#*/}
                    port=${rule_elem%/*}
                    rule_spec="$rule_spec -p $prot -m $prot --dport $port"
                    ;;
                +([0-9]|\.)?(/+([0-9])))
                    rule_spec="$rule_spec -s $rule_elem"
                    ;;
                *)
                    echo_warn "invalid rule: $rule_elem"
                    ;;
             esac
        done
        rule_spec=${rule_spec# }
        if [ -z "$rule_spec" ]; then
            continue
        fi
        rule_spec="INPUT $rule_spec -j ACCEPT"
        if grep -q -e "^-A $rule_spec" $TMPDIR/iptables_cur; then
            echo_info "A rule '$rule_spec' is already set."
        else
            echo_info "Append a rule '$rule_spec' to iptables."
            verbose_run iptables -I $rule_spec
        fi
    done
    iptables-save > $TMPDIR/iptables_new
    diff_cp $TMPDIR/iptables_new /etc/sysconfig/iptables
}

patch_resource_agents()
{
    local ra_ver=$(get_rpm_version resource-agents)
    if [ -z "$ra_ver" ]; then return 0; fi
    echo_info "Patch resource-agents $ra_ver"
    #
    # apache-conf.sh の source_envfiles で読み取った変数を
    # httpd に環境変数として渡すために export するようにパッチをあてる
    #
    if patch --dry-run -f -s -d/ -p1 -i $THIS_DIR/patches/apache-conf.sh.patch > /dev/null; then
        verbose_run patch -b -f -d/ -p1 -i $THIS_DIR/patches/apache-conf.sh.patch
    fi
    #
    # monitorの性能改善のためのパッチ(余分なrabbitmqctl呼び出しを削除)
    # users, permissions 情報のバックアップ・リストア処理改善のためのパッチ
    #
    for patch in $THIS_DIR/patches/rabbitmq-cluster*.patch; do
        if patch --dry-run -f -s -d/ -p1 -i $patch > /dev/null; then
            verbose_run patch -b -f -d/ -p1 -i $patch
        fi
    done
}

setup_ha_user()
{
    #
    # kompirad から pcs コマンドを操作できるように haclient グループに追加する
    #
    verbose_run usermod -a -G $KOMPIRA_HA_CLIENT $KOMPIRA_USER
}

cluster_wait_current_dc()
{
    local timeout=60
    ECHO_OPTIONS="-n" echo_info "Waiting Current DC"
    sleep 3
    while [ $timeout -gt 0 ]; do
        let timeout=$timeout-1
        if crm_mon -1 | grep "Current DC: NONE" > /dev/null; then
            echo -n "."
            sleep 1
            continue
        fi
        echo
        return 0
    done
    echo
    return 1
}

pcs_enter_maintenance_mode()
{
    echo_info "Enter the pacemaker in maintenance mode."
    verbose_run pcs property set maintenance-mode=true
}

pcs_leave_maintenance_mode()
{
    echo_info "Exit the pacemaker from maintenance mode."
    verbose_run pcs property set maintenance-mode=false
}

pcs_remove_resources()
{
    local pcs_opt=$@
    #
    # 既存のリソースを削除する
    #
    local group
    local res
    pcs_remove_constraints $pcs_opt
    local pcs_resource_config
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.10.0") ]; then
        pcs_resource_config="resource show --full"
    else
        pcs_resource_config="resource config"
    fi
    for group in $(pcs $pcs_opt $pcs_resource_config | grep 'Group:' | sed -re 's/.*: (\w+)/\1/'); do
        verbose_run pcs $pcs_opt resource delete $group
    done
    for res in $(pcs $pcs_opt $pcs_resource_config | grep 'Resource:' | sed -re 's/.*: (\w+).*/\1/'); do
        verbose_run pcs $pcs_opt resource delete $res
    done
}

pcs_remove_constraints()
{
    local pcs_opt=$@
    #
    # 既存の制約条件を削除する
    #
    local pcs_constraint_config
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.10.0") ]; then
        pcs_constraint_config="constraint show --full"
    else
        pcs_constraint_config="constraint config --full"
    fi
    local constraint
    for constraint in $(pcs $pcs_opt $pcs_constraint_config | grep 'id:' | sed -re 's/.*id:(.*)\)\s*$/\1/'); do
        verbose_run pcs $pcs_opt constraint remove $constraint
    done
}

pcs_setup_constraints()
{
    local pcs_opt=$@
    local res_name_pgsql
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.10.0") ]; then
        res_name_pgsql=ms_pgsql
    else
        res_name_pgsql=res_pgsql-clone
    fi
    local role_master
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.11.0") ]; then
        role_master="Master"
    else
        role_master="Promoted"
    fi
    #
    # *** 順序制約 ***
    # - pgsql が promote してから webserver を起動する
    #   (kompirad が早く起動して master になっていない pgsql に接続しようとするのを防ぐ)
    # - rabbitmqがstarted状態になってから webserverを起動する
    #
    verbose_run pcs $pcs_opt constraint order promote $res_name_pgsql then start webserver
    verbose_run pcs $pcs_opt constraint order set res_rabbitmq-clone role=Started set webserver
    #
    # *** 場所制約 ***
    # - webserver は pgsqlのマスタノードで実行可能
    # - pgsql マスタはrabbitmq が起動しているノードで実行可能
    #
    verbose_run pcs $pcs_opt constraint colocation add webserver with $role_master $res_name_pgsql
    verbose_run pcs $pcs_opt constraint colocation add $role_master $res_name_pgsql with res_rabbitmq-clone
}

pcs_set_property()
{
    # プロパティを16進ダンプした文字列で格納する（property の値には '=' を使用できないなど制約があるため）
    local key=$1
    local val=$(echo -n "$2" | $KOMPIRA_BIN/python -c "import sys;print(sys.stdin.buffer.read().hex())")
    shift 2
    local pcs_opt=$@
    verbose_run pcs property set $key=$val --force $pcs_opt
}

pcs_get_property()
{
    # プロパティ値を取得してデコードした結果を返す
    local key=$1
    local val=$(pcs property | grep $key:)
    echo -n ${val#*:} | $KOMPIRA_BIN/python -c "import sys;print(bytes.fromhex(sys.stdin.read()).decode())"
}

pcs_failcount_show()
{
    local res
    for res; do
        # [v1.5.0] pcs コマンドでは適切に failcount を扱えないので crm_failcount を利用する
        # pcs resource failcount show $res
        crm_failcount -r $res -G
    done
}

pcs_failcount_reset()
{
    local res
    for res; do
        # [v1.5.0] pcs コマンドでは適切に failcount を扱えないので crm_failcount を利用する
        # pcs resource failcount reset $res
        verbose_run crm_failcount -r $res -D
    done
}

pcs_show_status()
{
    echo_info "Display failcount for each resources."
    pcs_failcount_show res_vip res_httpd res_kompirad res_kompira_jobmngrd res_memcached res_pgsql res_rabbitmq
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.10.0") ]; then
        echo_info "Display constraint setings of resources."
        pcs constraint show
        echo_info "Display state of resources."
        pcs resource show
    else
        echo_info "Display constraint setings of resources."
        pcs constraint config
        echo_info "Display state of resources."
        pcs resource status
    fi
}

check_localname()
{
    if [ -z $HA_LOCALNAME ]; then
        HA_LOCALNAME=$(crm_node -n)
        if [ -z $HA_LOCALNAME ]; then
            abort_setup "Name of local node could not be determined."
        fi
    fi
}

check_othername()
{
    if [ -z $HA_OTHERNAME ]; then
        HA_OTHERNAME=$(crm_node -l | cut -d' ' -f2 | grep -v -w $(crm_node -n) | head -n 1)
        if [ -z $HA_OTHERNAME ]; then
            abort_setup "Name of other node could not be determined."
        fi
    fi
}

get_rmq_node()
{
    local node_name=$1
    if [ -z $node_name ]; then
        check_localname
        node_name=$HA_LOCALNAME
    fi
    crm_attribute -l reboot -N "$node_name" -n rmq-node-attr-res_rabbitmq -G -q 2>/dev/null
}

get_pgsql_score()
{
    local node_name=$1
    if [ -z $node_name ]; then
        check_localname
        node_name=$HA_LOCALNAME
    fi
    crm_attribute -l forever -N "$node_name" -n master-res_pgsql -G -q 2>/dev/null
}

sync_secret_keyfile()
{
    #
    # pgsql の シークレットキーファイルを同期する
    #
    echo_info "Syncronize PostgreSQL secret key file."
    local secret_key=$(pcs_get_property pgsql-secret-key)
    if [ -z $secret_key ]; then
        # 1.6.5 以前のバージョンの場合はプロパティがセットされていないため、ここでセットする
        pcs_set_property pgsql-secret-key "$(cat $DB_SECRET_KEYFILE)"
    elif [ "$secret_key" != "$(cat $DB_SECRET_KEYFILE)" ]; then
        cp -f $DB_SECRET_KEYFILE ${DB_SECRET_KEYFILE}.bak
        echo -n $secret_key > $DB_SECRET_KEYFILE
    fi
}

#
# クラスタ構成が正常状態になるまで待つ
# ---
#   正常状態とは各ノードの属性値が以下の状態となることを指す
#   - いずれかのノードの res_pgsql が Master (master-res_pgsql == 1001)
#   - 自ノードの res_pgsql が Master または Slave (master-res_pgsql >= 1000)
#   - ONLINE ノードの res_rabbitmq が Started (rmq-node-attr-res_rabbitmq == rabbit@<ノード名>)
#   - Webserver グループの各リソースが Started
#
wait_resources_stabilize()
{
    check_localname
    get_cluster_status
    local timeout=120
    local pgsql_slave_timeout=15
    local postgres_label="postgres"
    local rabbitmq_label="rabbitmq"
    local rabbitmq_prefix="rabbit@"
    local -A websrv_label=(["kompira_jobmngrd"]="jobmngrd")
    local postgres_res_width rabbitmq_res_width=16 websrv_res_width=9
    local lin_sep=" + " grp_sep=" | " res_sep=", "
    local result=1
    local tmp_crm_mon=$(mktemp)
    local nodes=()
    local websrv_resources=()
    local show_header=false
    local -A node_online pg_role rmq_role pg_score rmq_node web_role 
    local s_postgres s_rabbitmq s_webrole n_postgres n_rabbitmq r_webrole
    local pgsql_master pgsql_local rmq_local websrv_started
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.11.0") ]; then
        postgres_res_width=15
    else
        postgres_res_width=17
    fi

    ECHO_OPTIONS="-n" echo_info "Waiting for the resources to stabilize."

    # crm_mon の結果を XML で出力して各リソースの状態を確認する
    while [ $timeout -gt 0 ]; do
        let timeout=$timeout-1
        sleep 1
        crm_mon --as-xml > $tmp_crm_mon
        # ノード名一覧が取得できる状態になるのを待つ
        if [ ${#nodes[@]} -eq 0 ]; then
            nodes=($(xmllint --xpath "//nodes/node/@name" $tmp_crm_mon 2> /dev/null | sed -re 's/\s*name="([^"]+)"/\1 /g'))
            if [ ${#nodes[@]} -gt 0 ]; then
                echo
                echo_info "nodes[${#nodes[@]}]: ${nodes[*]} (local=$HA_LOCALNAME)"
                for node_name in "${nodes[@]}"; do
                    if [ $rabbitmq_res_width -lt $((10+${#rabbitmq_prefix}+${#node_name})) ]; then
                        rabbitmq_res_width=$((10+${#rabbitmq_prefix}+${#node_name}))
                    fi
                done
                show_header=true
            else
                echo -n "."
                continue
            fi
        fi
        # webserver リソース一覧を取得する (pacemaker 1 系の master 系では起動直後には取得できない)
        if [ ${#websrv_resources[@]} -eq 0 ]; then
            websrv_resources=($(xmllint --xpath '//resources/group[@id="webserver"]/resource/@id' $tmp_crm_mon 2> /dev/null | sed -re 's/\s*id="([^"]+)"/\1 /g'))
            if [ ${#websrv_resources[@]} -gt 0 ]; then
                show_header=true
            fi
        fi
        # ヘッダを表示する
        if $show_header; then
            local node_index=0 node_name res_id res_label
            local th_hline=("" "" "") th_label=("" "" "")
            for node_name in "${nodes[@]}"; do
                if [ "$node_name" != ${nodes[0]} ]; then
                    th_hline[0]+=$(printf "%${#res_sep}s" ""); th_label[0]+=$res_sep
                    th_hline[1]+=$(printf "%${#res_sep}s" ""); th_label[1]+=$res_sep
                fi
                th_hline[0]+=$(printf "%${postgres_res_width}s" "")
                th_label[0]+=$(printf "%${postgres_res_width}s" "$postgres_label[$node_index]");
                th_hline[1]+=$(printf "%${rabbitmq_res_width}s" "")
                th_label[1]+=$(printf "%${rabbitmq_res_width}s" "$rabbitmq_label[$node_index]");
                node_index=$(($node_index + 1))
            done
            for res_id in "${websrv_resources[@]}"; do
                if [ $res_id != ${websrv_resources[0]} ]; then
                    th_hline[2]+=$(printf "%${#res_sep}s" ""); th_label[2]+=$res_sep
                fi
                res_label=${res_id#res_}
                res_label=${websrv_label[$res_label]:-"$res_label"}
                th_hline[2]+=$(printf "%${websrv_res_width}s" "")
                th_label[2]+=$(printf "%${websrv_res_width}s" "$res_label")
            done
            th_hline="${th_hline[0]}${lin_sep}${th_hline[1]}${lin_sep}${th_hline[2]}"
            th_hline="${th_hline// /-}"
            th_label="${th_label[0]}${grp_sep}${th_label[1]}${grp_sep}${th_label[2]}"
            echo "$th_hline"
            echo "$th_label"
            echo "$th_hline"
            show_header=false
        fi
        #
        # リソースの状態を取得する
        #
        for node_name in "${nodes[@]}"; do
            node_online[$node_name]=$(xmllint --xpath "string(//nodes/node[@name='$node_name']/@online)" $tmp_crm_mon)
            pg_role[$node_name]=$(xmllint --xpath "string(//resources/clone/resource[@id='res_pgsql']/node[@name='$node_name']/../@role)" $tmp_crm_mon)
            rmq_role[$node_name]=$(xmllint --xpath "string(//resources/clone/resource[@id='res_rabbitmq']/node[@name='$node_name']/../@role)" $tmp_crm_mon)
            pg_score[$node_name]=$(xmllint --xpath "string(//node_attributes/node[@name='$node_name']/attribute[@name='master-res_pgsql']/@value)" $tmp_crm_mon)
            rmq_node[$node_name]=$(xmllint --xpath "string(//node_attributes/node[@name='$node_name']/attribute[@name='rmq-node-attr-res_rabbitmq']/@value)" $tmp_crm_mon)
        done
        for res_id in "${websrv_resources[@]}"; do
            web_role[$res_id]=$(xmllint --xpath "string(//resources/group[@id='webserver']/resource[@id='$res_id']/@role)" $tmp_crm_mon)
        done
        pgsql_master=false
        pgsql_local=false
        rmq_local=false
        websrv_started=true
        #
        # リソースの状態を確認しながら表示する
        #
        s_postgres=""
        for node_name in "${nodes[@]}"; do
            if [ "$node_name" != ${nodes[0]} ]; then s_postgres+=$res_sep; fi
            if [ "${node_online[$node_name]}" == "true" ]; then
                n_pgrole=${pg_role[$node_name]}
                n_postgres=${pg_score[$node_name]}
                # postgres の Master ノードが存在するか、自ノードが Master/Slave のいずれかであるかを確認する
                if [ "$n_postgres" == $PGSQL_MASTER_SCORE ]; then pgsql_master=true; fi
                if [ "$node_name" == $HA_LOCALNAME ] && [ -n "$n_postgres" ] && [ "$n_postgres" -ge $PGSQL_SLAVE_SCORE ]; then pgsql_local=true; fi
                n_pgrole="$n_pgrole($n_postgres)"
            else
                n_pgrole="OFFLINE"
            fi
            s_postgres+=$(printf "%${postgres_res_width}s" "$n_pgrole")
        done
        s_rabbitmq=""
        for node_name in "${nodes[@]}"; do
            if [ "$node_name" != ${nodes[0]} ]; then s_rabbitmq+=$res_sep; fi
            if [ "${node_online[$node_name]}" == "true" ]; then
                n_rmqrole=${rmq_role[$node_name]}
                n_rabbitmq=${rmq_node[$node_name]}
                # 自ノードで rabbitmq-server が起動しているかを確認する
                if [ "$node_name" == $HA_LOCALNAME ] && [ "$n_rabbitmq" == "$rabbitmq_prefix$node_name" ]; then rmq_local=true; fi
                n_rmqrole="$n_rmqrole($n_rabbitmq)"
            else
                n_rmqrole="OFFLINE"
            fi
            s_rabbitmq+=$(printf "%${rabbitmq_res_width}s" "$n_rmqrole")
        done
        s_webrole=""
        for res_id in "${websrv_resources[@]}"; do
            if [ $res_id != ${websrv_resources[0]} ]; then s_webrole+=$res_sep; fi
            r_webrole=${web_role[$res_id]}
            # webserver グループの各リソースが起動しているかを確認する
            if [ $r_webrole != "Started" ]; then websrv_started=false; fi
            s_webrole+=$(printf "%${websrv_res_width}s" "$r_webrole")
        done
        printf "%s${grp_sep}%s${grp_sep}%s\n" "$s_postgres" "$s_rabbitmq" "$s_webrole"
        #
        # リソースの状態を判定する
        #
        if $pgsql_master && $rmq_local && [ ${#websrv_resources[@]} -gt 0 ] && $websrv_started; then
            # すべてのリソースが確認できれば正常終了する
            if $pgsql_local; then
                result=0
                break
            fi
            # PostgreSQL (SLAVE) だけ起動できていない場合の異状判定短縮
            let pgsql_slave_timeout=$pgsql_slave_timeout-1
            if [ $pgsql_slave_timeout -le 0 ]; then
                break
            fi
        fi
    done
    rm -f $tmp_crm_mon
    echo "$th_hline"
    if ! $pgsql_master; then
        echo_error "PostgreSQL is not running as Master on any node."
    fi
    if ! $pgsql_local; then
        echo_error "PostgreSQL is not running on the local node."
    fi
    if ! $rmq_local; then
        echo_error "RabbitMQ is not running on the local node."
    fi
    if ! $websrv_started; then
        echo_error "One or more resources in the webserver group are not running."
    fi
    return $result
}

sync_corosync()
{
    # corosync の設定を対向ノードに同期する
    local othername="$1"
    local tmp_corosync="/tmp/corosync.conf.$$"
    verbose_run pcs cluster corosync $othername > $tmp_corosync
    exit_if_failed "$?" "Failed to sync corosync.conf"
    diff_cp $tmp_corosync /etc/corosync/corosync.conf
    verbose_run pcs cluster reload corosync
    rm -f $tmp_corosync
}

normalize_proxy_url()
{
    local url="$1"
    case "$url" in
        "" | http*://) url="";;
        http*://*) ;;
        *) url="http://$url" ;;
    esac
    echo $url
}

show_options()
{
    for opt in $@; do
        echo_param "$opt" "${!opt}"
    done
}

create_tmpdir()
{
    TMPDIR=$(mktemp -d --tmpdir=$(pwd) "$TMPDIR_TEMPLATE")
}

start_setup()
{
    echo_always \
        "****************************************************************" \
        "Kompira-$VERSION:" \
        "Start: ${SETUP_TYPE}" \
        ""
    show_options $SHOW_OPTIONS
}

exit_setup()
{
    local rc=${1:-0}
    echo_always \
        "" \
        "Finish: ${SETUP_TYPE} (status=$rc)" \
        "****************************************************************"
    sleep 1
    exit $rc
}

abort_setup()
{
    echo_error "" "$@" ""
    exit_setup 1
}
