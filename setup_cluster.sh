#!/bin/bash
#
# Copyright (c) 2012-2014 Fixpoint Inc. All rights reserved.
# ---
# Kompiraクラスタ構成セットアップスクリプト
#
# * NICは以下のように割当てる::
#   eth0 --- サービス提供用インタフェース
#   eth1 --- heartbeat用インタフェース
#
# * 各パラメータは以下のとおりとする
#                             primary         secondary
#   heartbeat ipaddress       192.168.99.1    192.168.99.2
#   hostname                  kompira-server1 kompira-server2
#
# * PostgreSQLのpostgresパスワードの設定は同じにしておくこと
#
shopt -s extglob
SETUP_TYPE="Setup the Kompira Cluster"
SETUP_LOG="setup_cluster.$$.log"
THIS_DIR=$(dirname $(readlink -f $0))

. $THIS_DIR/scripts/setup_utils.sh

HEARTBEAT_DEVICE=
HEARTBEAT_NETCIDR=192.168.99.0/24
CLUSTER_VIP=
CLUSTER_DEVICE=
PRIMARY_IP=
SECONDARY_IP=
# YUMOPT_FOR_HA=

SECONDARY=false
SLAVE_MODE=false
SKIP_HOSTS=false
SKIP_HBNET=false
SKIP_FIREWALL=false
SKIP_IPTABLES=false
MANUAL_HEARTBEAT=false
NO_JOBMNGR_SETUP=false
NO_CLUSTER_VIP=false
MANUAL_MODE=false
DRY_RUN=false

HACLUSTER_USER=hacluster
HACLUSTER_PASS=hacluster

#
# High-Availability パッケージ情報
#
PACKAGES_FOR_HA="pcs resource-agents-paf perl-Data-Dumper"
PCS_VERSION=

#
# Resource Agent (Amazon Linux 2 用)
#
RA_PAF_PKGURL="https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-${RHEL_VERSION}-${REQUIRES_ARCH}/resource-agents-paf-2.3.0-1.rhel${RHEL_VERSION}.noarch.rpm"

: ${HA_CLUSTER_NAME:=""}
: ${HA_HOSTNAME_PREFIX:="ha-kompira"}
: ${PRIMARY_SUFFIX:="1"}
: ${SECONDARY_SUFFIX:="2"}
: ${PRIMARY_IP_OFFSET:=1}
: ${SECONDARY_IP_OFFSET:=2}
: ${PCS_SETUP_OPTIONS:=""}
: ${PCS_TRANSPORT=}
: ${PCS_TOKEN=30000}
: ${PCS_CONSENSUS=}

: ${cluster_name:=}
: ${primary_name:=}
: ${secondary_name:=}
: ${primary_altname:=}
: ${secondary_altname:=}
: ${primary_ip:=}
: ${secondary_ip:=}
: ${local_hostname:=}
: ${other_hostname:=}
: ${local_ipaddr:=}
: ${other_ipaddr:=}

: ${heartbeat_baseaddr:=}
: ${heartbeat_ipaddr:=}
: ${cluster_nic:=}
: ${cluster_vip:=}
: ${cluster_netmask:=}

SHOW_OPTIONS="$SHOW_OPTIONS SECONDARY SLAVE_MODE NO_JOBMNGR_SETUP HA_HOSTNAME_PREFIX MANUAL_HEARTBEAT PRIMARY_IP SECONDARY_IP HEARTBEAT_NETCIDR CLUSTER_VIP DRY_RUN"
SHOW_PARAMS="cluster_name primary_name secondary_name heartbeat_baseaddr heartbeat_ipaddr cluster_nic cluster_vip cluster_netmask primary_ip secondary_ip local_ipaddr"

ipaddr2int()
{
    $PLATFORM_PYTHON -c "import socket; import struct; print(struct.unpack('>I', socket.inet_aton('$1'))[0])"
}

int2ipaddr()
{
    $PLATFORM_PYTHON -c "import socket; import struct; print(socket.inet_ntoa(struct.pack('>I', $1)))"
}

check_ipaddr()
{
    ipcalc -c $1
}

check_cidr()
{
    local cidr=$1
    echo $cidr | egrep '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/([0-9]{1,2})' >/dev/null && ipcalc -c $cidr
}

check_ipaddr_in_netcidr()
{
    local label=$1
    local ipaddr=$2
    local netcidr=$3
    local netmask=${netcidr#*/}
    #
    # ipaddr が netcidr の範囲に含まれていること、および
    # ネットワークまたはブロードキャストアドレスになっていないことをチェックする
    #
    if [ "$(ipcalc -n $ipaddr/$netmask)" != "$(ipcalc -n $netcidr)" ]; then
        echo_error "$label($ipaddr) not in $netcidr"
        return 1
    fi
    if [ "$(ipcalc -n $ipaddr/$netmask)" == "NETWORK=$ipaddr" ]; then
        echo_error "$label($ipaddr) is network address"
        return 1
    fi
    if [ "$(ipcalc -b $ipaddr/$netmask)" == "BROADCAST=$ipaddr" ]; then
        echo_error "$label($ipaddr) is broadcast address"
        return 1
    fi
    return 0
}

show_params()
{
    echo_info ""
    show_options $SHOW_PARAMS
    echo_info ""
}

set_params()
{
    echo_title "Preparing the parameters."

    if [ -n "$PRIMARY_NAME" ]; then
        primary_name="$PRIMARY_NAME"
    else
        primary_name="${HA_HOSTNAME_PREFIX}${PRIMARY_SUFFIX}"
    fi
    if [ -n "$SECONDARY_NAME" ]; then
        secondary_name="$SECONDARY_NAME"
    else
        secondary_name="${HA_HOSTNAME_PREFIX}${SECONDARY_SUFFIX}"
    fi

    #
    # ハートビート用 CIDR から、プライマリ／セカンダリ用 IP アドレスを計算する
    #
    if $MANUAL_HEARTBEAT; then
        primary_ip=$PRIMARY_IP
        secondary_ip=$SECONDARY_IP
    else
        heartbeat_baseaddr=${HEARTBEAT_NETCIDR%/*}
        primary_ip=$(int2ipaddr $(($(ipaddr2int $heartbeat_baseaddr)+$PRIMARY_IP_OFFSET)))
        secondary_ip=$(int2ipaddr $(($(ipaddr2int $heartbeat_baseaddr)+$SECONDARY_IP_OFFSET)))
    fi
    if ! $NO_CLUSTER_VIP; then
        cluster_vip=${CLUSTER_VIP%/*}
        cluster_netmask=${CLUSTER_VIP#*/}
    fi
    if [ -n "$CLUSTER_DEVICE" ]; then
        cluster_nic="$CLUSTER_DEVICE"
    fi
    #
    # クラスタ名称を生成する
    #
    cluster_name="${HA_CLUSTER_NAME}"
    if [ -z "$cluster_name" ]; then
        local cluster_id
        if ! $MANUAL_HEARTBEAT; then
            cluster_id="${HA_HOSTNAME_PREFIX}${HEARTBEAT_NETCIDR}"
        else
            cluster_id="${HA_HOSTNAME_PREFIX}${primary_ip}${secondary_ip}"
        fi
        cluster_name="ha-kompira-$(echo "$cluster_id" | sha1sum | cut -c1-6)"
    fi

    if ! $SECONDARY; then
        local_hostname=$primary_name
        other_hostname=$secondary_name
        local_ipaddr=$primary_ip
        other_ipaddr=$secondary_ip
        heartbeat_ipaddr=$primary_ip
        primary_altname=$HA_LOCALHOST
        secondary_altname=$HA_OTHERHOST
    else
        local_hostname=$secondary_name
        other_hostname=$primary_name
        local_ipaddr=$secondary_ip
        other_ipaddr=$primary_ip
        heartbeat_ipaddr=$secondary_ip
        primary_altname=$HA_OTHERHOST
        secondary_altname=$HA_LOCALHOST
    fi
}

check_params()
{
    if ! $MANUAL_HEARTBEAT; then
        echo_title "Check the paramters"
        #
        # 各アドレスが HEARTBEAT_NETCIDR の範囲にあるかをチェック
        #
        local result=0
        check_ipaddr_in_netcidr "heartbeat_ipaddr" $heartbeat_ipaddr $HEARTBEAT_NETCIDR
        let result+=$?
        check_ipaddr_in_netcidr "primary_ip" $primary_ip $HEARTBEAT_NETCIDR
        let result+=$?
        check_ipaddr_in_netcidr "secondary_ip" $secondary_ip $HEARTBEAT_NETCIDR
        let result+=$?
        exit_if_failed $result "invalid heartbeat-netaddr ($HEARTBEAT_NETCIDR)"
    fi
}

check_environ()
{
    echo_title "Check the current environment"
    if [ -n "$PROXY_URL" ]; then
        echo_debug "settings http_proxy for install: $PROXY_URL"
        echo_debug "settings no_proxy for install: $NO_PROXY"
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export HTTP_PROXY="$PROXY_URL"
        export HTTPS_PROXY="$PROXY_URL"
        export no_proxy="$NO_PROXY"
    fi

    check_arch
    check_system
    check_subscription

    #
    # RHEL High Availability アドオンのチェック
    #
    #if ! $OFFLINE_MODE; then
    #    if [ $SYSTEM == "RHEL" ]; then
    #        if ! $RHUI_MODE; then
    #            #
    #            # RHEL では High-Availability リポジトリを有効にする
    #            #
    #            verbose_run yum repolist --enablerepo="${RHEL_HA_REPONAME// /,}"
    #            exit_if_failed "$?" "Addon 'RHEL High Availability' is not available"
    #        fi
    #    fi
    #fi

    if ! $OFFLINE_MODE; then
        # オンラインインストールする前に、既存 extra パッケージのモジュールを事前に無効化する
        disable_kompira_extra_module
        # GPG KEY を更新する
        update_rpm_gpg_key
    else
        # オフラインインストールのために extra パッケージのモジュールを有効化する
        enable_kompira_extra_module
    fi

    if [ -n "$HEARTBEAT_DEVICE" ]; then
        #
        # HEARTBEAT_DEVICE が指定されている場合、デバイスが存在することを確認する
        #
        ip link show $HEARTBEAT_DEVICE > /dev/null
        exit_if_failed "$?" "Device $HEARTBEAT_DEVICE does not exist!"
        #
        # ハートビートIPアドレスが設定されているかチェックする
        #
        if ip -4 -o addr show scope global dev $HEARTBEAT_DEVICE | grep -w -q $local_ipaddr; then
            # 指定したデバイスに既に設定済みなのでなにもしない
            echo_info "Address $local_ipaddr configured on $HEARTBEAT_DEVICE already."
            SKIP_HBNET=true
        elif ip -4 -o addr show scope global | grep -w -q $local_ipaddr; then
            # 指定したデバイス以外で既にアドレスが設定されている場合はエラー
            abort_setup "Address $local_ipaddr configured on other device!"
        fi
    elif $MANUAL_HEARTBEAT; then
        #
        # HEARTBEAT_DEVICE が指定されておらず、ハートビート手動設定の場合は、
        # いずれかのデバイスに $local_ipaddr が設定済みであることを確認する
        #
        if ! ip -4 -o addr show scope global | grep -w -q $local_ipaddr; then
            abort_setup "$?" "Address $local_ipaddr does not configured!"
        fi
        SKIP_HBNET=true
    fi

    #
    # Kompira 用 virtualenv が設定されていること [1.4.11]
    #
    if [ ! -x $KOMPIRA_ENV/bin/pip ]; then
        abort_setup "Kompira virtualenv ($KOMPIRA_ENV) is not configured"
    fi
    local -x PIP=$KOMPIRA_ENV/bin/pip

    #
    # Kompira がインストールされていること／1.4以上であることを確認する
    #
    local kompira_version=$(get_kompira_version)
    case $kompira_version in
        "")
            abort_setup "Kompira is not installed"
            ;;
        "1.[^0-3].*")
            abort_setup "Kompira version 1.4 or higher is required! ($kompira_version)"
            ;;
        *)
            echo_info "Confirmed Kompira version: $kompira_version"
            ;;
    esac

    #
    # postgresql に kompira 用カスタム設定ディレクトリがあることを確認する [1.5.5]
    #
    if ! $SLAVE_MODE; then
        if [ ! -d $CUR_PG_DATADIR/kompira.conf.d ]; then
            abort_setup "Postgresql custom config directory not found!: $CUR_PG_DATADIR/kompira.conf.d"
        fi
    fi
}

install_cluster_packages()
{
    echo_title "Install RPM packages for High Availability"
    local yum_options
    #
    # オンラインインストールに必要なリポジトリを有効化する
    #
    if ! $OFFLINE_MODE; then
        if [ $SYSTEM == "RHEL" ]; then
            # RHEL の HighAvailability パッケージ用リポジトリを有効化する
            verbose_run yum-config-manager --enable "$HA_REPONAME_RHEL" > /dev/null
        elif [ -n "$HA_REPONAME_OTHERS" ]; then
            # 上記以外の OS 向けに HighAvailability パッケージ用リポジトリを有効化する
            verbose_run yum-config-manager --enable "$HA_REPONAME_OTHERS" > /dev/null
        fi
        if [ $SYSTEM != "AMZN" ]; then
            # resource-agents-paf をインストールするため pgdg-common リポジトリを有効化する
            install_pgdg_redhat_repo
            verbose_run yum-config-manager --enable pgdg-common > /dev/null
        fi
    fi
    #
    # HA 構成に必要なパッケージをインストールする
    #
    verbose_run yum clean all
    if ! $OFFLINE_MODE && [ $SYSTEM == "AMZN" ]; then
        #
        # Amazon Linux 2 では resource-agents-paf がレポジトリに含まれていないため、直接インストールする
        #
        YUM_OPTION="$yum_options --enablerepo=amzn*" yum_localinstall $RA_PAF_PKGURL
        PACKAGES_FOR_HA=${PACKAGES_FOR_HA/resource-agents-paf/}
    fi
    YUM_OPTION=$yum_options yum_install $PACKAGES_FOR_HA
    #
    # PCSのバージョンを取得
    #
    PCS_VERSION=$(get_rpm_version pcs)
}

setup_nic_nmcli()
{
    local dev=$1
    local ipaddr=$2

    echo_info "Configure NIC $dev settings [nmcli]"
    if ! LANG= nmcli connection show $dev >/dev/null 2>&1; then
       LANG= verbose_run nmcli connection add type ethernet ifname $dev con-name $dev
    fi
    LANG= verbose_run nmcli connection modify $dev ipv4.method manual +ipv4.addresses $ipaddr
    LANG= verbose_run nmcli connection modify $dev connection.autoconnect yes
    echo_info "Restart the NIC $dev"
    LANG= verbose_run nmcli connection down $dev
    LANG= verbose_run nmcli connection up $dev
    exit_if_failed "$?" "Failed to restart NIC $dev"
}

setup_heartbeat_network()
{
    local dev=$HEARTBEAT_DEVICE
    local ipaddr="$heartbeat_ipaddr/${HEARTBEAT_NETCIDR#*/}"
    setup_nic_nmcli $dev $ipaddr
}

setup_hosts()
{
    echo_info "Configure /etc/hosts settings"

    local hosts_file=/etc/hosts
    #
    # primary_name, secondary_name の記述があれば一旦削除する
    #
    verbose_run sed -r \
                -e "s/\s+($primary_name|$secondary_name|$HA_LOCALHOST|$HA_OTHERHOST)\b/ /g" \
                -e "s/\s+$//" \
                $hosts_file > $TMPDIR/hosts
    #
    # primary_ip の行の先頭に $primary_name $primary_altname を追記する
    #
    if grep -q "^\s*${primary_ip//./\.}\b" $TMPDIR/hosts; then
        verbose_run sed -r -e "s/^\s*(${primary_ip//./\.})\b\s*(.*)/\1 $primary_name $primary_altname \2/" -i $TMPDIR/hosts
    else
        echo "$primary_ip $primary_name $primary_altname" >> $TMPDIR/hosts
    fi
    #
    # secondary_ip の行の先頭に $secondary_name $secondary_altname を追記する
    #
    if grep -q "^\s*${secondary_ip//./\.}\b" $TMPDIR/hosts; then
        verbose_run sed -r -e "s/^\s*(${secondary_ip//./\.})\b\s*(.*)/\1 $secondary_name $secondary_altname \2/" -i $TMPDIR/hosts
    else
        echo "$secondary_ip $secondary_name $secondary_altname" >> $TMPDIR/hosts
    fi
    # IP アドレスだけになってしまった行は削除する
    verbose_run sed -r -e "/^[0-9.]+$/d" -i $TMPDIR/hosts
    diff_cp $TMPDIR/hosts $hosts_file
}

setup_network()
{
    echo_title "Configure Network settings"

    if ! $SKIP_HBNET; then
        setup_heartbeat_network
    fi
    if ! $SKIP_FIREWALL; then
        if is_active_service firewalld; then
            # "2224/tcp" "4369/tcp" "5672/tcp" "15672/tcp" "25672/tcp"
            setup_firewalld "2224/tcp" "$other_ipaddr/32"
        elif is_active_service iptables; then
            setup_iptables "$other_ipaddr/32"
        fi
    fi
    if ! $SKIP_HOSTS; then
        setup_hosts
    fi
}

setup_apache()
{
    echo_title "Configure the Apache service."
    diff_cp $THIS_DIR/config/cluster/status.conf /etc/httpd/conf.d/status.conf

    echo_info "Disable and stop the Apache service."
    service_disable httpd
    service_stop httpd
}

setup_pgsql()
{
    echo_title "Configure the PostgreSQL service"

    verbose_run $INSTALL -o postgres -g postgres -m 700 -d "$CUR_PG_BASEDIR/pg_archive"

    echo_info "Disable and stop the PostgreSQL service"
    service_disable $CUR_PG_SERVICE
    service_stop $CUR_PG_SERVICE

    #
    # postgresql.conf への設定追加
    #
    pgsql_conf_include_standby $CUR_PG_DATADIR/postgresql.conf > $TMPDIR/postgresql.conf
    diff_install -o postgres -g postgres -m 0600 $TMPDIR/postgresql.conf $CUR_PG_DATADIR/postgresql.conf
    expand_template $THIS_DIR/config/cluster/standby.conf > $TMPDIR/standby.conf.tmp
    PG_MAJVER=$CUR_PG_MAJVER pgsql_convert_standby_conf $TMPDIR/standby.conf.tmp > $TMPDIR/standby.conf
    diff_install -o postgres -g postgres -m 0600 $TMPDIR/standby.conf $CUR_PG_BASEDIR/standby.conf

    if ! $SLAVE_MODE; then
        echo_title "Configure PostgreSQL streaming replication settings."
        verbose_run sed -re "/^host replication $PG_REPL_USER/d" $CUR_PG_DATADIR/pg_hba.conf > $TMPDIR/pg_hba.conf
        echo "host replication $PG_REPL_USER $primary_name trust" >> $TMPDIR/pg_hba.conf
        echo "host replication $PG_REPL_USER $secondary_name trust" >> $TMPDIR/pg_hba.conf
        diff_install -o postgres -g postgres -m 600 $TMPDIR/pg_hba.conf $CUR_PG_DATADIR/pg_hba.conf

        verbose_run rm -f $CUR_PG_BASEDIR/tmp/PGSQL.lock

        echo_info "Create PostgreSQL replication user: $PG_REPL_USER"
        service_start $CUR_PG_SERVICE
        pgsql_create_repluser $PG_REPL_USER $PG_REPL_PASS
        service_stop $CUR_PG_SERVICE
    fi
}

setup_rabbitmq()
{
    echo_title "Configure RabbitMQ clustering settings."
    if [ ! -d $RABBITMQ_CONFD_DIR ]; then
        verbose_run mkdir $RABBITMQ_CONFD_DIR
    fi

    echo_info "Disable the RabbitMQ service"
    service_disable rabbitmq-server
    service_stop rabbitmq-server

    echo_info "Configure rabbitmq cluster configs."
    echo -n "$cluster_name" > $TMPDIR/dot.erlang.cookie
    diff_install -o $RABBITMQ_USER -g $RABBITMQ_GROUP -m 400 $TMPDIR/dot.erlang.cookie /var/lib/rabbitmq/.erlang.cookie

    # 50-cluster.conf がカスタマイズされている場合は上書きせず .new ファイルとしてコピーする [v1.6.8]
    expand_template $THIS_DIR/config/rabbitmq/50-cluster.conf > $TMPDIR/rabbitmq-50-cluster.conf
    copy_new_conf_file $TMPDIR/rabbitmq-50-cluster.conf $RABBITMQ_CONFD_DIR/50-cluster.conf

    # rabbitmq-env.conf に NODENAME を設定する（他の設定は保持する）
    local NODENAME="rabbit@$local_hostname"
    if grep -E -q '^NODENAME\s*=' /etc/rabbitmq/rabbitmq-env.conf 2>/dev/null; then
        verbose_run sed -r -e "s|^(NODENAME)\s*=.*|\1=$NODENAME|" /etc/rabbitmq/rabbitmq-env.conf > $TMPDIR/rabbitmq-env.conf
    else
        (cat /etc/rabbitmq/rabbitmq-env.conf 2>/dev/null; echo "NODENAME=$NODENAME") > $TMPDIR/rabbitmq-env.conf
    fi
    diff_cp $TMPDIR/rabbitmq-env.conf /etc/rabbitmq/rabbitmq-env.conf
}

setup_memcached()
{
    echo_info "Disable and stop the memcached service."
    service_disable memcached
    service_stop memcached
}


setup_kompira()
{
    echo_title "Disable and stop the Kompira-Daemon service"

    service_disable kompirad
    service_disable kompira_jobmngrd
    service_stop kompirad
    service_stop kompira_jobmngrd

    #
    # systemd では Requires 設定を除外する（依存関係は pacemaker 側で制御する）
    # kompira をアップデートすると /usr/lib/systemd/system/kompira*.service を更新するが、
    # その影響を受けないようにするために /etc/systemd/system に配置する
    #
    local svcname
    for svcname in kompirad.service kompira_jobmngrd.service; do
        verbose_run sed -re "s/^\s*(Requires\s*=.*)/# \1/" /usr/lib/systemd/system/$svcname > $TMPDIR/$svcname
        diff_cp $TMPDIR/$svcname /etc/systemd/system/$svcname
    done
    verbose_run $SYSTEMCTL daemon-reload

    # スクリプトを更新する
    diff_install -m 644 $THIS_DIR/scripts/setup_utils.sh $KOMPIRA_BIN/setup_utils.sh
    diff_install -m 755 $THIS_DIR/scripts/sync_master.sh $KOMPIRA_BIN/sync_master.sh
}

cluster_restart()
{
    cluster_stop
    cluster_start
}

cluster_start()
{
    verbose_run pcs cluster start
}

cluster_stop()
{
    verbose_run pcs cluster stop --force
}

setup_pcsd()
{
    echo_title "Configure pcsd settings"
    local transport_options
    local totem_options
    echo "$HACLUSTER_PASS" | LANG= verbose_run passwd $HACLUSTER_USER --stdin
    service_enable pcsd
    service_start pcsd
    if [ -z "$PCS_TRANSPORT" ]; then
        if [ $RHEL_VERSION -le 7 ]; then
            PCS_TRANSPORT="udpu"
        else
            PCS_TRANSPORT="knet"
        fi
    fi
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.10.0") ]; then
        # pacemaker 1.x setup
        if ! $SECONDARY; then
            transport_options="--transport $PCS_TRANSPORT"
            # corosync をセットアップする
            verbose_run pcs cluster auth --local --force $primary_name -u $HACLUSTER_USER -p "$HACLUSTER_PASS"
            verbose_run pcs cluster setup --local --enable --name "$cluster_name" $primary_name $secondary_name $transport_options $PCS_SETUP_OPTIONS
            # corosync パラメータを更新する
            rm -f $TMP/corosync.sed
            if [ -n "$PCS_TOKEN" ]; then
                echo -e "/token:/d\n/transport:/a \\    token: $PCS_TOKEN" >> $TMP/corosync.sed
            fi
            if [ -n "$PCS_CONSENSUS" ]; then
                echo -e "/consensus:/d\n/transport:/a \\    consensus: $PCS_CONSENSUS" >> $TMP/corosync.sed
            fi
            if [ -f $TMP/corosync.sed ]; then
                verbose_run cat $TMP/corosync.sed
                verbose_run sed -f $TMP/corosync.sed /etc/corosync/corosync.conf > $TMPDIR/corosync.conf
                exit_if_failed "$?" "Failed to update corosync.conf"
                diff_cp $TMPDIR/corosync.conf /etc/corosync/corosync.conf
                verbose_run pcs cluster reload corosync
            fi
        else
            verbose_run pcs cluster auth --force $primary_name $secondary_name -u $HACLUSTER_USER -p "$HACLUSTER_PASS"
            sync_corosync $primary_name
            verbose_run pcs cluster node add $secondary_name --force
        fi
    else
        # pacemaker 2.x setup
        if ! $SECONDARY; then
            transport_options="transport $PCS_TRANSPORT"
            # cluster をセットアップする
            verbose_run pcs host auth $primary_name -u $HACLUSTER_USER -p "$HACLUSTER_PASS"
            verbose_run pcs cluster setup --enable "$cluster_name" $primary_name $transport_options $PCS_SETUP_OPTIONS
            # corosync パラメータを更新する
            if [ -n "$PCS_TOKEN" ]; then
                totem_options="$totem_options token=$PCS_TOKEN"
            fi
            if [ -n "$PCS_CONSENSUS" ]; then
                totem_options="$totem_options consensus=$PCS_CONSENSUS"
            fi
            if [ -n "$totem_options" ]; then
                verbose_run pcs cluster config update totem $totem_options
            fi
        else
            verbose_run pcs host auth $primary_name $secondary_name -u $HACLUSTER_USER -p "$HACLUSTER_PASS"
            sync_corosync $primary_name
            verbose_run pcs cluster node add $secondary_name --force
        fi
        # generate authkey
        echo_info "generate authkey"
        verbose_run $KOMPIRA_BIN/python -c "import sys; import hashlib; sys.stdout.buffer.write(hashlib.scrypt(b'$cluster_name',salt=b'ha-kompira-authkey',n=1024,r=1,p=1,dklen=256))" > $TMPDIR/authkey
        verbose_run install -m 400 $TMPDIR/authkey /etc/corosync/authkey
    fi
}

stop_pacemaker()
{
    ## if $CLUSTER_RUNNING; then
    echo_title "Stop the Pacemaker"
    cluster_stop
    ## fi
}

clear_https_proxy()
{
    # pcs コマンド実行が影響を受けないように https proxy 設定をクリアしておく
    HTTPS_PROXY=
    https_proxy=
}

setup_pacemaker()
{
    setup_pcsd
    patch_resource_agents
    echo_info "Enable the Pacemaker service"
    service_enable pacemaker
}

start_slave()
{
    echo_title "Start the Pacemaker as SLAVE"
    pgsql_replica $HA_OTHERHOST
    cluster_start
    cluster_wait_current_dc
    sync_secret_keyfile
}

start_master()
{
    echo_title "Start the Pacemaker as MASTER"
    cluster_start
    cluster_wait_current_dc
}

setup_cluster()
{
    local pcs_opt
    echo_title "Configure clustering settings."
    local timeout=60
    while [ $timeout -gt 0 ]; do
        let timeout=$timeout-1
        if verbose_run pcs cluster cib $TMPDIR/cib-org.xml; then
            break
        fi
        sleep 1
    done
    if [ $timeout -eq 0 ]; then
        abort_setup "Failed to get cib"
    fi
    verbose_run cp $TMPDIR/cib-org.xml $TMPDIR/cib-new.xml
    pcs_opt="-f $TMPDIR/cib-new.xml"
    pcs_setup_stonith $pcs_opt
    pcs_remove_resources $pcs_opt
    pcs_setup_resources $pcs_opt
    pcs_setup_constraints $pcs_opt
    pcs_set_property pgsql-secret-key "$(cat $DB_SECRET_KEYFILE)" $pcs_opt
    verbose_run pcs cluster cib-push $TMPDIR/cib-new.xml
    if $CLUSTER_CONFIGURED; then
        pcs_failcount_reset res_rabbitmq res_pgsql
    fi
}

pcs_setup_stonith()
{
    local pcs_opt=$@
    verbose_run pcs $pcs_opt property set no-quorum-policy="ignore" stonith-enabled="false"
}

pcs_setup_resources()
{
    local pcs_opt=$@
    local RES_VIP=""
    local RES_KOMPIRA_JOBMNGRD=""
    local params_res_vip
    local role_master
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.11.0") ]; then
        role_master="Master"
    else
        role_master="Promoted"
    fi
    #
    # create webserver group resources
    #
    verbose_run pcs $pcs_opt resource create res_httpd ocf:heartbeat:apache \
        configfile="/etc/httpd/conf/httpd.conf" envfiles="/etc/sysconfig/httpd" port="80" statusurl="http://localhost/.login" \
        op start interval="0" timeout="60s" \
        op monitor interval="5s" timeout="20s" \
        op stop interval="0" timeout="60s"
    exit_if_failed "$?" "Failed to create res_httpd"
    verbose_run pcs $pcs_opt resource create res_kompirad systemd:kompirad \
        op start interval="0" timeout="300s" \
        op monitor interval="5s" timeout="20s" \
        op stop interval="0" timeout="60s"
    exit_if_failed "$?" "Failed to create res_kompirad"
    if ! $NO_JOBMNGR_SETUP; then
        verbose_run pcs $pcs_opt resource create res_kompira_jobmngrd systemd:kompira_jobmngrd \
            op start interval="0" timeout="60s" \
            op monitor interval="5s" timeout="20s" \
            op stop interval="0" timeout="60s"
        exit_if_failed "$?" "Failed to create res_kompira_jobmngrd"
        RES_KOMPIRA_JOBMNGRD="res_kompira_jobmngrd"
    fi
    if ! $NO_CLUSTER_VIP; then
        params_res_vip="ip=$cluster_vip cidr_netmask=$cluster_netmask"
        if [ -n "$cluster_nic" ]; then
            params_res_vip="$params_res_vip nic=$cluster_nic"
        fi
        verbose_run pcs $pcs_opt resource create res_vip ocf:heartbeat:IPaddr2 \
            $params_res_vip \
            op monitor interval="10s"
        exit_if_failed "$?" "Failed to create res_vip"
        RES_VIP="res_vip"
    fi
    verbose_run pcs $pcs_opt resource create res_memcached systemd:memcached \
        op start interval="0s" timeout="20s" \
        op stop interval="0s" timeout="20s" \
        op monitor interval="5s" timeout="20s"
    exit_if_failed "$?" "Failed to create res_memcached"
    # issue #2019: pcs 0.10.14-6 / resource-agents-paf 4.9.0-34 以降では --force オプションを付けないとエラーになる
    verbose_run pcs --force $pcs_opt resource create res_pgsql ocf:heartbeat:pgsqlms \
        bindir="$CUR_PG_BINDIR" \
        pgdata="$CUR_PG_DATADIR" \
        op start   timeout="60s" interval="0s" on-fail="restart" \
        op monitor timeout="60s" interval="7s" on-fail="restart" \
        op monitor timeout="60s" interval="5s" on-fail="restart" role="$role_master" \
        op promote timeout="60s" interval="0s" on-fail="restart" \
        op demote  timeout="60s" interval="0s" on-fail="restart" \
        op stop    timeout="60s" interval="0s" on-fail="ignore" \
        op notify  timeout="60s" interval="0s"
    exit_if_failed "$?" "Failed to create res_pgsql"
    verbose_run pcs $pcs_opt resource create res_rabbitmq ocf:heartbeat:rabbitmq-cluster \
        set_policy="all ^.* {\"ha-mode\":\"all\"}" \
        op monitor interval="10s" timeout="60s" \
        op start interval="0" timeout="600" \
        op stop interval="0" timeout="120"
    exit_if_failed "$?" "Failed to create res_rabbitmq"

    verbose_run pcs $pcs_opt resource group add webserver res_memcached res_kompirad $RES_KOMPIRA_JOBMNGRD res_httpd $RES_VIP
    verbose_run pcs $pcs_opt resource meta webserver target-role="Started"
    if [ $(ver2num $PCS_VERSION) -lt $(ver2num "0.10.0") ]; then
        verbose_run pcs $pcs_opt resource master ms_pgsql res_pgsql master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
    else
        verbose_run pcs $pcs_opt resource promotable res_pgsql master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
    fi
    verbose_run pcs $pcs_opt resource clone res_rabbitmq clone-max=2 notify=true
    verbose_run pcs $pcs_opt resource defaults resource-stickness="INFINITY" migration-threshold="1"
}

final_check()
{
    # ssl_options.fail_if_no_peer_cert=true、かつ、冗長構成で相互の CA 証明書がバンドルされていない場合は、
    # 相互に CA 証明書をコピーしてバンドルすることを勧めるメッセージを表示する
    if grep -Eq "^\s*ssl_options.fail_if_no_peer_cert\s*=\s*true" /etc/rabbitmq/conf.d/*.conf &&
        [ -f $KOMPIRA_SSL_DIR/certs/kompira-bundle-ca.crt ] &&
        [ $(grep "# $KOMPIRA_SSL_DIR/ca-source" $KOMPIRA_SSL_DIR/certs/kompira-bundle-ca.crt | wc -l) -lt 2 ];
    then
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
}

usage_exit()
{
    cat <<EOF
Usage: `basename $0` [OPTIONS] <cluster-vip>/<prefix>

  --cluster-name=NAME           Specify the cluster name (up to 15 characters).
  --primary                     Setup for primary server.
  --secondary                   Setup for secondary server.
  --master-mode                 Setup with master mode.
  --slave-mode                  Setup with slave mode.
  --without-vip                 Setup without VIP.
  --without-jobmanager          Setup without job manager.
  --hostname-prefix=PREFIX_NAME Specify prefix of hostname.
  --heartbeat-netaddr=NETWORK_ADDRESS/PREFIX
                                Specify network address for heartbeat.
  --manual                      Setup parameters manually.
  --manual-heartbeat            Specify heartbeat network manually.
  --heartbeat-device=DEVICE     Specify network interface for heartbeat.
  --heartbeat-primary=NETWORK_ADDRESS
                                Manual address setting for heartbeat-primary.
  --heartbeat-secondary=NETWORK_ADDRESS
                                Manual address setting for heartbeat-secondary.
  --token=TOKEN                 Token timeout (milliseconds).
  --consensus=CONSENSUS         Consensus timeout (milliseconds).
  --cluster-device=DEVICE       Specify network inteface for VIP.
  --proxy=PROXY                 Specify a proxy in the form
                                [user:passwd@]proxy.server:port.
  --noproxy=HOSTS               Comma-separated list of hosts which do not use proxy.
  --dry-run                     Check the parameters without actually installing.
  --offline                     Setup in offline mode.
  --help                        Show this message.

EOF
    exit 1
}

parse_options()
{
    OPTIONS=`getopt -q -o '' -l cluster-name:,primary,secondary,master-mode,slave-mode,without-vip,without-jobmanager,manual-heartbeat,hostname-prefix:,heartbeat-netaddr:,heartbeat-primary:,heartbeat-secondary:,heartbeat-device:,cluster-device:,transport:,token:,consensus:,proxy:,noproxy:,manual,offline,dry-run,help -- "$@"`
    [ $? != 0 ] && usage_exit

    local slave_mode
    eval set -- "$OPTIONS"
    while true
    do
        arg="$1"
        case "$arg" in
            --cluster-name)
                HA_CLUSTER_NAME="$2"
                shift ;;
            --primary)
                SECONDARY=false
                SLAVE_MODE=false ;;
            --secondary)
                SECONDARY=true
                SLAVE_MODE=true  ;;
            --master-mode)
                slave_mode=false ;;
            --slave-mode)
                slave_mode=true ;;
            --without-vip)
                NO_CLUSTER_VIP=true ;;
            --without-jobmanager)
                NO_JOBMNGR_SETUP=true ;;
            --manual)
                MANUAL_MODE=true ;;
            --manual-heartbeat)
                MANUAL_HEARTBEAT=true ;;
            --hostname-prefix)
                HA_HOSTNAME_PREFIX="$2"
                shift ;;
            --heartbeat-netaddr)
                HEARTBEAT_NETCIDR="$2"
                shift ;;
            --heartbeat-device)
                HEARTBEAT_DEVICE="$2"
                shift ;;
            --heartbeat-primary)
                PRIMARY_IP="$2"
                shift ;;
            --heartbeat-secondary)
                SECONDARY_IP="$2"
                shift ;;
            --cluster-device)
                CLUSTER_DEVICE="$2"
                shift ;;
            --transport)
                PCS_TRANSPORT="$2"
                shift ;;
            --token)
                PCS_TOKEN="$2"
                shift ;;
            --consensus)
                PCS_CONSENSUS="$2"
                shift ;;
            --proxy)
                PROXY_URL=$(normalize_proxy_url $2)
                shift ;;
            --noproxy)
                NO_PROXY=$2
                shift ;;
            --offline)
                OFFLINE_MODE=true
                SETUP_TYPE="$SETUP_TYPE (offline-mode)" ;;
            --dry-run)
                DRY_RUN=true ;;
            --) shift; break ;; # 引数は無視
            *) usage_exit ;;
        esac
        shift
    done

    if [ -n "$slave_mode" ]; then
        SLAVE_MODE=$slave_mode
    fi

    if [ -z "$HA_HOSTNAME_PREFIX" ]; then
        echo "ERROR: hostname-prefix must be non-empty string."
        echo
        usage_exit
    fi

    if $MANUAL_HEARTBEAT; then
        if [ -z "$PRIMARY_IP" -o -z "$SECONDARY_IP" ]; then
            echo "ERROR: option --heartbeat-primary and --heartbeat-secondary are required when manual-heartbeat."
            echo
            usage_exit
        fi
        if ! check_ipaddr $PRIMARY_IP; then
            echo "ERROR: invalid heartbeat-primary: $PRIMARY_IP"
            echo
            usage_exit
        fi
        if ! check_ipaddr $SECONDARY_IP; then
            echo "ERROR: invalid heartbeat-secondary: $SECONDARY_IP"
            echo
            usage_exit
        fi
    else
        if [ -z "$HEARTBEAT_DEVICE" ]; then
            echo "ERROR: option --heartbeat-device is required"
            echo
            usage_exit
        fi
        if ! check_cidr $HEARTBEAT_NETCIDR; then
            echo "ERROR: invalid heartbeat-netaddr: $HEARTBEAT_NETCIDR"
            echo
            usage_exit
        fi
    fi

    if ! $NO_CLUSTER_VIP; then
        if ! $SLAVE_MODE && ! check_cidr "$1"; then
            echo "ERROR: invalid <cluster-vip>/<prefix>."
            echo
            usage_exit
        else
            CLUSTER_VIP="$1"
        fi
    fi
}


################################################################

parse_options "$@"
exec > >(tee $SETUP_LOG) 2>&1
create_tmpdir
start_setup
if ! $MANUAL_MODE; then
    set_params
fi
show_params
check_params
check_root
check_environ
if $DRY_RUN ; then
    exit_setup
fi

install_cluster_packages
stop_pacemaker
setup_network
setup_apache
setup_kompira
setup_pgsql
setup_rabbitmq
setup_memcached
clear_https_proxy
setup_pacemaker
# オフラインインストールで利用した extra パッケージのモジュールは無効化しておく
if $OFFLINE_MODE; then
    disable_kompira_extra_module
fi
setup_ha_user
if $SLAVE_MODE; then
    start_slave
else
    start_master
    setup_cluster
fi
wait_resources_stabilize
exit_if_failed $? "Resources were not stable."
final_check
exit_setup
