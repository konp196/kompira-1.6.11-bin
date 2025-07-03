#! /bin/sh
#
# kompira_backup.sh
#

THIS_DIR=$(dirname $(readlink -f $0))
. $THIS_DIR/setup_utils.sh

BACKUP_VERSION=1.0.0

: ${BACKUP_PROCESS:=true}
: ${DUMPDATA_OPTS:="--traceback"}
: ${DUMPDATA_EXCLUDES:=""}

init()
{
    if [ "$EUID" -ne 0 ]; then
        echo_error "Please run as root"
        exit 1
    fi
    if [ ! -x $KOMPIRA_BIN/manage.py ]; then
        echo_error "$KOMPIRA_BIN/manage.py not found"
        exit 1
    fi
    if ! pgsql_has_kompira_table; then
        echo_error "kompira table is not exist."
        exit 1
    fi
    local backup_dir=$(dirname $KOMPIRA_BACKUP)
    if [ ! -d $backup_dir ]; then
        echo_error "backup directory $backup_dir is not exist."
        exit 1
    fi
}

rotate_backup()
{
    if [ -f $KOMPIRA_BACKUP ]; then
        local latest_backup=$(ls -t $KOMPIRA_BACKUP.* 2>/dev/null | head  -1)
        local index=1
        if [ -n "$latest_backup" ]; then
            let index="${latest_backup##*.}+1"
        fi
        while [ -f "$KOMPIRA_BACKUP.$index" ]; do
            let index=$index+1
        done
        echo_info "Rotate existing backup file $KOMPIRA_BACKUP to $(basename $KOMPIRA_BACKUP.$index)."
        verbose_run sudo -u $KOMPIRA_USER mv $KOMPIRA_BACKUP "$KOMPIRA_BACKUP.$index"
    fi
}

backup_database()
{
    echo_info "Start database backup."
    local dumpdata_opts=$DUMPDATA_OPTS
    # loaddata 時にエラーになる contenttypes, auth.permission は除外する
    local dumpdata_excludes="$DUMPDATA_EXCLUDES contenttypes auth.permission sessions axes"
    # プロセスオブジェクトをバックアップしない場合は kompira.{process,processconfig,snapshot} を除外する
    if ! $BACKUP_PROCESS; then
        dumpdata_excludes+=" kompira.process kompira.processconfig kompira.snapshot"
    fi
    local dumpdata_exclude
    for dumpdata_exclude in $dumpdata_excludes; do
        dumpdata_opts+=" -e $dumpdata_exclude"
    done
    verbose_run $KOMPIRA_BIN/manage.py dumpdata $dumpdata_opts --output $KOMPIRA_BACKUP
    if [ $? -ne 0 ]; then
        echo_error "Database backup failed."
        rm -f $KOMPIRA_BACKUP
        exit 1
    fi
    chown $KOMPIRA_USER:$KOMPIRA_USER $KOMPIRA_BACKUP
    echo_info "Database backup succeeded."
    local du_backup=$(LANG= du -sk $KOMPIRA_BACKUP | tail -1 | cut -f1)
    local df_destdir=$(echo $(LANG= df -k $(dirname $KOMPIRA_BACKUP) 2>/dev/null | tail -1) | cut -d' ' -f4)
    echo_info "Backup file: $KOMPIRA_BACKUP"
    echo_info "$(printf "Backup size:%'12d KiB" $du_backup)"
    echo_info "$(printf "Free space:%'13d KiB" $df_destdir)"
    echo_info "Backup kompira.process: $BACKUP_PROCESS"
}

init
rotate_backup
backup_database
