#! /bin/bash

: ${INSTALL:=install}
: ${SCP_REMOTEUSER:=root}
: ${SCP_OPTIONS:=}
: ${SCP:=scp -q -p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SCP_OPTIONS}
: ${CHECK_ROOT:=true}
: ${CHOWN_CERT:=true}

: ${KOMPIRA_HOME:=/opt/kompira}
: ${KOMPIRA_SSL_DIR:="$KOMPIRA_HOME/ssl"}
: ${KOMPIRA_AMQP_USER:=kompira}
: ${KOMPIRA_GROUP:=kompira}
: ${RABBITMQ_GROUP:=rabbitmq}

: ${SSL_KEYTYPE=rsa:2048}
: ${SSL_CERT_DAYS=10000}

: ${CLUSTER_CIB_FILE:="/var/lib/pacemaker/cib/cib.xml"}


ECHO_OPTIONS=
ECHO_PREFIX=
ECHO_POSTFIX=

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

ssl_init()
{
    if [ ! -d $KOMPIRA_SSL_DIR ]; then
        echo_info "Create Kompira SSL directory: $KOMPIRA_SSL_DIR"
        verbose_run $INSTALL -m 755 -d $KOMPIRA_SSL_DIR
        verbose_run $INSTALL -m 755 -d $KOMPIRA_SSL_DIR/certs
    fi
}

ssl_create_local_ca()
{
    # Kompira local CA 証明書を作成
    ssl_init
    if [ ! -d $KOMPIRA_SSL_DIR/ca-source ]; then
        verbose_run $INSTALL -m 755 -d $KOMPIRA_SSL_DIR/ca-source
    fi
    if [ ! -f $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.crt ]; then
        echo_info "Create local CA certificate"
        verbose_run openssl req -x509 -newkey $SSL_KEYTYPE -nodes -days $SSL_CERT_DAYS -out $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.crt -keyout $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.key -subj "/CN=Kompira local CA ($(hostname -s))"
        verbose_run chmod 444 $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.crt
        verbose_run chmod 400 $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.key
    fi
}

ssl_update_bundle_ca()
{
    # Kompira bundle CA 証明書を更新
    # $KOMPIRA_SSL_DIR/ca-source にある証明書を単一ファイルに結合する
    # TODO: 適切な証明書であるかチェックする
    if [ ! -d $KOMPIRA_SSL_DIR/ca-source ]; then
        echo_error "directory $KOMPIRA_SSL_DIR/ca-source does not exist!"
        exit 1
    fi
    local bundle_ca=$KOMPIRA_SSL_DIR/certs/kompira-bundle-ca.crt
    if [ -f $bundle_ca ]; then
        verbose_run chmod 600 $bundle_ca
        verbose_run truncate -s 0 $bundle_ca
    fi
    for cafile in $KOMPIRA_SSL_DIR/ca-source/*.crt; do
        (echo "# $cafile"; cat $cafile; echo "") >> $bundle_ca
    done
    verbose_run chmod 444 $bundle_ca
}

ssl_pcs_property_set_local_ca()
{
    # 自ノードの kompira-local-ca.crt の内容を pcs property に設定する
    # KEY: ${ノード名}-local-ca
    # VAL: CA証明書(DERバイナリ)を16進数化した文字列
    if [ ! -e $CLUSTER_CIB_FILE ]; then
        echo_error "Pacemaker is not configured."
        exit 1
    fi
    local ha_localname=$(crm_node -n)
    local key="$ha_localname-local-ca"
    local val=$(openssl x509 -in $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.crt -inform pem -outform der | /opt/kompira/bin/python -c "import sys;print(sys.stdin.buffer.read().hex())")
    verbose_run pcs property set $key=$val --force "$@"
    echo_info ""
    echo_info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo_info ""
    echo_info "PLEASE EXECUTE '$0 get-other-ca-with-pcs' ON OTHER KOMPIRA SERVER"
    echo_info ""
    echo_info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

ssl_pcs_property_get_other_ca()
{
    # 他ノードの kompira-local-ca.crt の内容を pcs property から取得する
    # 取得したら当該 pcs property は削除する
    if [ ! -e $CLUSTER_CIB_FILE ]; then
        echo_error "Pacemaker is not configured."
        exit 1
    fi
    local ha_othername=$(crm_node -l | cut -d' ' -f2 | grep -v -w $(crm_node -n) | head -n 1)
    local key="$ha_othername-local-ca"
    local val=$(pcs property | grep $key:)
    echo -n ${val#*:} | /opt/kompira/bin/python -c "import sys;sys.stdout.buffer.write(bytes.fromhex(sys.stdin.read()))" | verbose_run openssl x509 -inform der -outform pem -out $KOMPIRA_SSL_DIR/ca-source/kompira-other-ca.crt
    verbose_run pcs property unset $key
}

ssl_scp_get_other_ca()
{
    # 冗長系対向ノードの local CA 証明書を scp コマンドで取得する
    # 対向ノードから証明書をコピーするため scp でのパスワード入力が必要になる
    local other_node=$1
    if [ ! -e $CLUSTER_CIB_FILE ]; then
        echo_error "Pacemaker is not configured."
        exit 1
    fi
    shift || true
    if [ -z "$other_node" ]; then
        other_node=$(/opt/kompira/bin/python -c 'import socket; print(socket.gethostbyname("ha-kompira-other"))')
    fi
    echo_info ""
    echo_info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo_info ""
    echo_info "Start copying the SSL/CA certificates from the other kompira server with scp."
    echo_info ""
    echo_info "PLEASE ENTER THE PASSWORD OF THE OTHER KOMPIRA SERVER ($other_node) FOR SCP."
    echo_info ""
    echo_info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo_info ""
    verbose_run $SCP "$@" $SCP_REMOTEUSER@$other_node:$KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.crt $KOMPIRA_SSL_DIR/ca-source/kompira-other-ca.crt
}

ssl_sync_server_certs()
{
    # kompira_jobmngrd, kompira_sendevt のみインストールしたノードに
    # kompira サーバから発行済み証明書を取得して導入する
    local server_node=$1
    if [ -z "$server_node" ]; then
        echo_error "usage: sync-server-certs server_node"
        exit 1
    fi
    shift
    echo_info ""
    echo_info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo_info ""
    echo_info "Start copying the SSL/CA certificates from the kompira server with scp."
    echo_info ""
    echo_info "PLEASE ENTER THE PASSWORD OF THE REMOTE KOMPIRA SERVER ($server_node) FOR SCP."
    echo_info ""
    echo_info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo_info ""
    verbose_run $SCP $SCP_REMOTEUSER@$server_node:$KOMPIRA_SSL_DIR/certs/\{kompira-bundle-ca.crt,amqp-client-kompira\{.crt,.key}} $KOMPIRA_SSL_DIR/certs/ "$@"
    if $CHOWN_CERT; then
        verbose_run chown :$KOMPIRA_GROUP $KOMPIRA_SSL_DIR/certs/{kompira-bundle-ca.crt,amqp-client-kompira{.crt,.key}}
    fi
}

ssl_create_cert()
{
    # $KOMPIRA_SSL_DIR/certs/ に新しい SSL 証明書を作成する
    local certname=$1
    local subject=$2
    if [ -z "$certname" ] || [ -z "$subject" ]; then
        echo_error "usage: create-cert certname subject"
        exit 1
    fi
    if echo -n "$certname" | grep -E '[ \/:;*?"<>|]'; then
        echo_error "invalid certname: '$certname'"
        exit 1
    fi
    echo_info "Create SSL (self-signed) certificate: $certname"
    verbose_run openssl req -new -newkey $SSL_KEYTYPE -nodes -sha256 -out $KOMPIRA_SSL_DIR/certs/$certname.csr -keyout $KOMPIRA_SSL_DIR/certs/$certname.key -subj "$subject"
    verbose_run openssl x509 -req -days $SSL_CERT_DAYS -in $KOMPIRA_SSL_DIR/certs/$certname.csr -out $KOMPIRA_SSL_DIR/certs/$certname.crt -CA $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.crt -CAkey $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.key -CAcreateserial
    verbose_run chmod 640 $KOMPIRA_SSL_DIR/certs/$certname{.crt,.key,.csr}
    if [ "$(stat -c %a $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.srl)" != "600" ]; then
        verbose_run chmod 600 $KOMPIRA_SSL_DIR/ca-source/kompira-local-ca.srl
    fi
}

ssl_server_setup()
{
    if [ -f $KOMPIRA_SSL_DIR/.server_setup ]; then
        echo_info "This node is already set up as a server."
        return
    fi
    if [ -f $KOMPIRA_SSL_DIR/.client_setup ]; then
        echo_error "This node is already set up as a client."
        exit 1
    fi
    if ! rpm -q rabbitmq-server > /dev/null; then
        echo_error "Package rabbitmq-server is not installed."
        exit 1
    fi
    echo_title "Setup Kompira SSL environment (server)"
    ssl_init
    # Kompira local CA 証明書を作成
    ssl_create_local_ca
    ssl_update_bundle_ca
    # AMQP 用サーバ証明書を作成
    # rabbitmq-server がアクセスできるようにパーミッションを調整
    if [ ! -f $KOMPIRA_SSL_DIR/certs/amqp-server.crt ]; then
        echo_info "Create SSL (self-signed) certificate for amqp server"
        ssl_create_cert amqp-server "/CN=$(hostname)"
        if $CHOWN_CERT; then
            verbose_run chown :$RABBITMQ_GROUP $KOMPIRA_SSL_DIR/certs/amqp-server{.crt,.key,.csr}
        fi
    fi
    # AMQP 用クライアント証明書を作成
    # kompira_jobmngrd がアクセスできるようにパーミッションを調整
    # kompira_sendevt を実行するユーザが証明書にアクセスできる必要があることに注意
    if [ ! -f $KOMPIRA_SSL_DIR/certs/amqp-client-$KOMPIRA_AMQP_USER.crt ]; then
        echo_info "Create SSL (self-signed) certificate for amqp client"
        ssl_create_cert amqp-client-$KOMPIRA_AMQP_USER "/CN=$KOMPIRA_AMQP_USER"
        if $CHOWN_CERT; then
            verbose_run chown :$KOMPIRA_GROUP $KOMPIRA_SSL_DIR/certs/amqp-client-$KOMPIRA_AMQP_USER{.crt,.key,.csr}
        fi
    fi
    touch $KOMPIRA_SSL_DIR/.server_setup
}

ssl_client_setup()
{
    local kompira_server=$1
    if [ -f $KOMPIRA_SSL_DIR/.client_setup ]; then
        echo_info "This node is already set up as a client."
        return
    fi
    if [ -f $KOMPIRA_SSL_DIR/.server_setup ]; then
        echo_error "This node is already set up as a server."
        exit 1
    fi
    if [ -z "$kompira_server" ]; then
        echo_error "usage: client-setup kompira-server"
        exit 1
    fi
    shift
    echo_title "Setup Kompira SSL environment (client)"
    ssl_init
    ssl_sync_server_certs "$kompira_server" "$@"
    touch $KOMPIRA_SSL_DIR/.client_setup
}

check_root()
{
    if $CHECK_ROOT && [ $(whoami) != root ]; then
        echo_error "Please execute as root user."
        exit 1
    fi
}

usage()
{
    cat <<__EOF__
usage: ssl_utils.sh command [options]
commands for setup:
  server-setup                      Set up as a server node. (for rabbitmq-server)
  client-setup kompira-server       Set up as a client node. (for kompira_jobmngrd, kompira_sendevt)

commands for maintenance:
  update-bundle-ca                  Bundle multiple CA certificates into one.
  create-local-ca                   Create a local CA certificate to sign the SSL certificate for Kompira.
  create-cert certname subject      Create a new SSL certificate.

commands for cluster environment:
  get-other-ca [other-server]       Get the CA certificate from the other server with scp command, and update bundle CA.
  get-other-ca-with-pcs             Get the CA certificate from the other server with pcs property, and update bundle CA.
  set-local-ca-with-pcs             Set the local CA certificate to pcs property as a prep for get-other-ca-with-pcs.

These commands must be executed as the root user.
The commands "client-setup" and "get-other-ca" require password input for scp.
__EOF__
}

main()
{
    local command=$1
    shift || true
    case "$command" in
        "help"|"")
            usage
            ;;
        "server-setup")
            check_root
            ssl_server_setup "$@"
            ;;
        "client-setup")
            check_root
            ssl_client_setup "$@"
            ;;
        "update-bundle-ca")
            check_root
            ssl_update_bundle_ca "$@"
            ;;
        "create-local-ca")
            check_root
            ssl_create_local_ca "$@"
            ;;
        "create-cert")
            check_root
            ssl_create_cert "$@"
            ;;
        "get-other-ca")
            check_root
            ssl_scp_get_other_ca "$@"
            ssl_update_bundle_ca
            ;;
        "get-other-ca-with-pcs")
            check_root
            ssl_pcs_property_get_other_ca "$@"
            ssl_update_bundle_ca
            ;;
        "set-local-ca-with-pcs")
            check_root
            ssl_pcs_property_set_local_ca "$@"
            ;;
        *)
            echo "ERROR: invalid command '$command'; type 'help' for usage."
            exit 1
            ;;
    esac
}

set -e
set -o pipefail
main "$@"