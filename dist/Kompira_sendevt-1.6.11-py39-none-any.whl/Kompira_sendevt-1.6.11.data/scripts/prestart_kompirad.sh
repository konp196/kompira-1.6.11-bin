#! /bin/bash
shopt -s extglob
THIS_DIR=$(dirname $(readlink -f $0))

. $THIS_DIR/setup_utils.sh

KOMPIRAD_LOG=$KOMPIRA_LOG_DIR/kompirad.log
#
# Kompiraのシステムインポートデータは 'en' と 'ja' の言語のみサポートしている。
# LANG が ja* 以外の場合は、 'en' をインストールする
#
LANGUAGE_CODE='en'
case "$LANG" in
    ja*) LANGUAGE_CODE="ja" ;;
    *) ;;
esac

check_service_status()
{
    #
    # kompirad が起動中は処理させない
    #
    if is_active_service kompirad; then
        echo_error "kompirad is running!"
        exit 1
    fi
    #
    # pgsql の recovery mode が 'f' のときだけ DB を操作できる
    #
    timeout=20
    while [ $timeout -gt 0 ]; do
        let timeout=$timeout-1 1
        if [ "$(pgsql_is_in_recovery)" == "f" ]; then
            echo_info "PostgreSQL is running in master mode."
            break
        fi
        echo_warn "Waiting for PostgreSQL become a master..."
        sleep 1
    done
    if [ $timeout -eq 0 ]; then
        echo_error "PostgreSQL is recovery mode!"
        exit 1
    fi
    #
    # rabbitmq が開始しているときだけユーザ設定できる
    #
    timeout=20
    while [ $timeout -gt 0 ]; do
        let timeout=$timeout-1 1
        if rabbitmqctl eval 'application:which_applications().' | grep -q '{rabbit,'; then
            echo_info "RabbitMQ is running."
            break
        fi
        echo_warn "Waiting for RabbitMQ to start..."
        sleep 1
    done
    if [ $timeout -eq 0 ]; then
        echo_error "RabbitMQ is stopped!"
        exit 1
    fi
}

check_kompira_database()
{
    #
    # kompira DB にテーブルがなければ初期化する
    #
    if ! pgsql_has_kompira_table; then
        touch $KOMPIRA_VAR_DIR/startup/{do_migrate,do_import_data,do_update_packages_info}
    fi
}

get_latest_migration()
{
    for path in $KOMPIRA_VAR_DIR/migrations/*-*.py; do
        local migrate=$(basename $path)
        echo ${migrate%-*.py}
    done | sort -nr | head -n 1
}

create_migration_data()
{
    echo_info "Create migration data."

    local current=$(get_object_version)
    for path in $KOMPIRA_VAR_DIR/migrations/*-*.py; do
        [ -e $path ] || continue   # migrations/*-*.py が空の場合はスキップする
        local migrate=$(basename $path)
        local version=${migrate%-*.py}
        if [[ $version -gt $current ]]; then
            verbose_run $KOMPIRA_BIN/manage.py shell < $path > $KOMPIRA_VAR_DIR/migrations/${version}.dat
        fi
    done
}

import_migration_data()
{
    echo_info "Import migration data."

    local current=$(get_object_version)
    for path in $KOMPIRA_VAR_DIR/migrations/*.dat; do
        [ -e $path ] || continue   # migrations/*.dat が空の場合はスキップする
        local migrate=$(basename $path)
        local version=${migrate%.dat}
        if [[ $version -gt $current ]]; then
            $KOMPIRA_BIN/manage.py import_data --overwrite $path
            set_object_version $version
        fi
    done
}

do_rabbitmq_init()
{
    #
    # rabbitmq-server に kompira 用ユーザを追加する
    #
    if [ -f /etc/rabbitmq/kompira_user.conf ]; then
        . /etc/rabbitmq/kompira_user.conf
    fi
    if ! rabbitmqctl list_users -s | grep -w "^$KOMPIRA_AMQP_USER"; then
        echo_info "Create rabbitmq user: $KOMPIRA_AMQP_USER"
        rabbitmqctl add_user "$KOMPIRA_AMQP_USER" "$KOMPIRA_AMQP_PASSWORD"
        rabbitmqctl set_permissions --vhost / "$KOMPIRA_AMQP_USER" '.*' '.*' '.*'
        rabbitmqctl set_user_tags "$KOMPIRA_AMQP_USER" administrator
    else
        rabbitmqctl change_password "$KOMPIRA_AMQP_USER" "$KOMPIRA_AMQP_PASSWORD"
    fi
    #
    # rabbitmq-server の全ての機能フラグを有効化する
    #
    local tmp_feature_flags=$(mktemp)
    echo_info "Check feature flags in rabbitmq-server"
    rabbitmqctl list_feature_flags --silent 2>/dev/null > $tmp_feature_flags
    if grep -q 'unavailable$' $tmp_feature_flags; then
        # unavailable なフラグが存在する場合は有効化しない（冗長構成アップデート途中）
        cat $tmp_feature_flags
        echo_warn "The unavailable flag is present, so enabling is not performed"
    elif grep -q 'disabled$' $tmp_feature_flags; then
        # unavailable が存在せず disabled なフラグが存在する場合は全機能フラフを有効化する
        cat $tmp_feature_flags
        echo_info "Enable all feature flags in rabbitmq-server"
        verbose_run rabbitmqctl enable_feature_flag all
        verbose_run rabbitmqctl list_feature_flags --silent
    fi
    rm -f $tmp_feature_flags
}

do_migrate()
{
    #
    # $KOMPIRA_VAR_DIR/startup/do_migrate があれば、データベースを更新する
    #
    if [ -f $KOMPIRA_VAR_DIR/startup/do_migrate ]; then
        echo_info "Install pgcrypto extension."
        psql -U $PGSQL_USER -d $KOMPIRA_PG_DATABASE -c "CREATE EXTENSION IF NOT EXISTS pgcrypto"
        echo_info "Migrate database."
        verbose_run $KOMPIRA_BIN/manage.py migrate -v1 --noinput
        if [ -f $KOMPIRA_VAR_DIR/startup/do_restore ]; then
            if [ -f $KOMPIRA_BACKUP ]; then
                echo_info "Flush the database before restoring backup data"
                verbose_run $KOMPIRA_BIN/manage.py flush -v1 --noinput
                echo_info "Restore backup data: $KOMPIRA_BACKUP"
                verbose_run $KOMPIRA_BIN/manage.py loaddata --traceback --ignorenonexistent $KOMPIRA_BACKUP
                if [ $? != 0 ]; then
                    echo_error "Failed to restore backup"
                fi
            else
                echo_warn "Backup not found: $KOMPIRA_BACKUP"
            fi
            rm -f $KOMPIRA_VAR_DIR/startup/do_restore
        fi
        if [ "$($KOMPIRA_BIN/manage.py dumpdata --pks 1 kompira.user)" == "[]" ]; then
            echo_info "Load initial fixtures."
            verbose_run $KOMPIRA_BIN/manage.py loaddata -v1 bootstrap_data-$LANGUAGE_CODE.json
            #
            # オブジェクトバージョンを最新にする
            #
            local latest=$(get_latest_migration)
            set_object_version $latest
        else
            #
            # マイグレーションデータを作成する
            #
            create_migration_data
        fi
        rm -f $KOMPIRA_VAR_DIR/startup/do_migrate
    fi
}

do_import_data()
{
    #
    # $KOMPIRA_VAR_DIR/startup/do_import_data があれば、ファイルをインポートする
    #
    if [ -f $KOMPIRA_VAR_DIR/startup/do_import_data ]; then
        echo_info "Import essential objects."
        $KOMPIRA_BIN/manage.py import_data --overwrite --force-mode $KOMPIRA_VAR_DIR/exported/{types-$LANGUAGE_CODE.dat,startup-$LANGUAGE_CODE.dat,nodetypes.dat,utilities.dat}
        $KOMPIRA_BIN/manage.py import_data $KOMPIRA_VAR_DIR/exported/styles-$LANGUAGE_CODE.dat
        #
        # マイグレーションデータのインポート
        #
        import_migration_data

        rm -f $KOMPIRA_VAR_DIR/startup/do_import_data
    fi
}

do_update_packages_info()
{
    #
    # $KOMPIRA_VAR_DIR/startup/do_update_packages_info があれば、パッケージ情報を更新する
    #
    if [ -f $KOMPIRA_VAR_DIR/startup/do_update_packages_info ]; then
        echo_info "Collect and update packages information."
        $KOMPIRA_BIN/manage.py packages_info --collect --update --traceback && rm -f $KOMPIRA_VAR_DIR/startup/do_update_packages_info || true
    fi
}

set -eu
set -o pipefail
if [ ! -f $KOMPIRAD_LOG ]; then
    touch $KOMPIRAD_LOG
    chown kompira:kompira $KOMPIRAD_LOG
fi
exec >>$KOMPIRAD_LOG 2>&1
echo_info "starting pre-start of kompirad [$LANGUAGE_CODE]"
check_service_status
check_kompira_database
#
# 冗長系で開始した場合はシークレットキーファイルを同期する
#
if [ -e $CLUSTER_CIB_FILE ] && pcs property > /dev/null 2>&1; then
    sync_secret_keyfile
fi
do_rabbitmq_init
do_migrate
do_import_data
do_update_packages_info
