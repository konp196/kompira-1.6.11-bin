#! /bin/sh
#
# kompira_dump.sh
#

THIS_DIR=$(dirname $(readlink -f $0))
. $THIS_DIR/setup_utils.sh

DUMP_VERSION=1.1.0
LANG=

: ${BASEDIR:=.}
: ${DUMPNAME:="kompira_dump-$(date +%Y%m%d-%H%M%S)"}
: ${DUMP_DAYS:=30}
: ${DUMP_DATABASE_LIMIT:=100000000}
: ${DUMP_DATABASE_FORCE:=false}
: ${DUMP_DATABASE_OPTIONS:="--traceback -e contenttypes -e auth.permission -e sessions -e process"}
: ${DUMP_EXPORT_FORCE:=false}
: ${DUMP_EXPORT_OPTIONS="--owner-mode"}
: ${DUMP_EXPORT_PATH:="/"}

init()
{
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: Please run as root"
        exit 1
    fi

    # I/O とタスクの優先度を下げておく
    ionice -c 2 -n 7 -p $$ > /dev/null
    renice -n +10 $$ > /dev/null

    # 収集先のディレクトリ名を決定
    basepath=$(readlink -f $BASEDIR)
    dumpdir="$basepath/$DUMPNAME"
    run mkdir $dumpdir || exit 1

    # after_date より新しいログを収集する
    after_date=$(date +"%Y-%m-%d" --date "$DUMP_DAYS days ago")
}

compress()
{
    echo "compressing..."
    (cd $basepath;
     tar zcf $DUMPNAME.tar.gz $DUMPNAME;
     rm -rf $DUMPNAME
    )
    echo "$basepath/$DUMPNAME.tar.gz"
}

run()
{
    verbose_run "$@"
}

do_dump()
{
    local name=$1
    shift
    echo "========== $name ==========" > /dev/stderr
    run mkdir "$dumpdir/$name" || exit 1
    (
        cd "$dumpdir/$name";
        $*
    )
    echo "---------- $name ----------" > /dev/stderr
}

dump_system()
{
    run cp -a /etc/*-release ./
    run printenv > env.txt
    run who -aH > who.txt
    run ps axufww > ps.txt
    run top -bc -n 1 > top.txt
    run vmstat -t -n 1 3 > vmstat.txt
    run free -lk > free.txt
    run df -ah > df.txt
    if $SYSTEMD; then
        run systemctl status > systemctl-status.txt
        run systemctl status '*' > systemctl-status-all.txt
    else
        run service --status-all > service-status.txt
        run chkconfig --list > chkconfig-list.txt
    fi
    run yum repolist > yum-repolist.txt
    run yum list installed > yum-list-installed.txt
    run rpm -qa > rpm-qa.txt
    run $KOMPIRA_BIN/pip freeze > pip-freeze.txt
    run sysctl -a > sysctl.txt
    run lsmod > lsmod.txt
    mkdir ./proc
    for f in /proc/{version,*info,*stat}; do
        run cat $f > ./$f
    done
    (run tar -cf - /var/log/{dmesg,messages}) | (tar -xf -)
    (run tar -cf - -N $after_date /var/log/messages-*) | (tar -xf -)
    (run tar -cf - /var/run) | (tar -xf -)
}

dump_network()
{
    run ip -s link > ip-link.txt
    run ip addr > ip-addr.txt
    run ip route > ip-route.txt

    if is_active_service firewalld; then
        run firewall-cmd --list-all-zones > firewall-list-all-zones.txt
    elif is_active_service iptables; then
        run iptables -L -v > iptables.txt
        run iptables-save > iptables-save.txt
    fi
    if is_runnable netstat; then
        run netstat -na > netstat.txt
    fi
    if is_runnable ss; then
        run ss -nap > ss.txt
    fi
    if is_runnable traceroute; then
        run traceroute -n 8.8.8.8 > traceroute.txt
    fi
    run curl -kv -x "$PROXY_URL" "https://api.bitbucket.org/2.0/repositories/kompira/package/" > https-bitbucket.txt 2>&1
    (run tar -cf - /etc/udev/rules.d/) | (tar -xf -)
}

dump_apache()
{
    _service_status httpd > status.txt
    run apachectl -t > configtest.txt
    (run tar -cf - -N $after_date /var/log/httpd) | (tar -xf -)
    (run tar -cf - /etc/httpd) | (tar -xf -)
}

dump_rabbitmq()
{
    _service_status rabbitmq-server > status.txt
    run rabbitmqctl report > report.txt
    (run find /var/log/rabbitmq -type f -and \( -name "startup_*" -or -mtime "-$DUMP_DAYS" \) | xargs tar -cf -) | (tar -xf -)
}

dump_postgresql()
{
    _service_status $CUR_PG_SERVICE > status.txt
    run psql -U $KOMPIRA_PG_USER -xc "SELECT * FROM pg_stat_activity;" > pg_stat_activity.txt
    run psql -U $KOMPIRA_PG_USER -xc "SELECT pg_size_pretty(pg_database_size('$KOMPIRA_PG_DATABASE'));" > pg_database_size.txt
    run psql -U $KOMPIRA_PG_USER -c "SELECT * FROM pg_locks;" > pg_locks.txt
    run psql -U $KOMPIRA_PG_USER -c "SELECT l.pid, db.datname, c.relname, l.locktype, l.mode FROM pg_locks l LEFT JOIN pg_class c ON l.relation=c.relfilenode LEFT JOIN pg_database db ON l.database = db.oid ORDER BY l.pid;" > pg_locks_cocked.txt
    (run tar -cf - $CUR_PG_BASEDIR/{data/pg_log,pgstartup.log}) | (tar -xf -)
    (run tar -cf - -N $after_date /var/log/postgresql) | (tar -xf -)
}

dump_kompira()
{
    run $KOMPIRA_BIN/kompirad --version > version.txt
    run $KOMPIRA_BIN/manage.py license_info > license-info.txt
    if pgsql_has_kompira_table; then
        #
        # プロセス情報をダンプする
        #
        run $KOMPIRA_BIN/manage.py process --list --active > process-active-list.txt
        run $KOMPIRA_BIN/manage.py process --list --finish --tail=1000 > process-finished-list.txt
        run $KOMPIRA_BIN/manage.py process --list --all --started-since="-${DUMP_DAYS}days" --format=export > process-${DUMP_DAYS}-days.json
        #
        # DBサイズが DUMP_DATABASE_LIMIT 以下、または DUMP_DATABASE_FORCE が true のとき dumpdata する
        #
        local database_size=$(psql -U $KOMPIRA_PG_USER -Atc "SELECT pg_database_size('$KOMPIRA_PG_DATABASE');")
        if [ $database_size -le $DUMP_DATABASE_LIMIT ] || $DUMP_DATABASE_FORCE; then
            run $KOMPIRA_BIN/manage.py dumpdata $DUMP_DATABASE_OPTIONS > dumpdata.json
        fi
        #
        # DUMP_EXPORT_FORCE が true のとき、DUMP_EXPORT_PATH 以下を export_data する
        #
        if $DUMP_EXPORT_FORCE; then
            run $KOMPIRA_BIN/manage.py export_data --file=exportdata.json $DUMP_EXPORT_OPTIONS $DUMP_EXPORT_PATH
        fi
    fi
    run cp -a $KOMPIRA_HOME/kompira.conf ./
    run cp -a $KOMPIRA_VAR_DIR/kompira.lic ./
    (run tar -cf - -N $after_date $KOMPIRA_LOG_DIR) | (tar -xf -)
}

dump_HA()
{
    (run tar -cf - /var/log/{cluster,pcsd,pacemaker.log}) | (tar -xf -)
    _service_status corosync > corosync_status.txt
    _service_status pacemaker > pacemaker_status.txt
    run crm_mon -Afro1 > crm_mon_status.txt
}

dump()
{
    cat <<EOF
###
### kompira_dump ver $DUMP_VERSION
### dump started: $(date '+%Y-%m-%d %H:%M:%S')
###
EOF
    do_dump "system" dump_system
    do_dump "network" dump_network
    do_dump "apache" dump_apache
    do_dump "rabbitmq" dump_rabbitmq
    do_dump "postgresql" dump_postgresql
    do_dump "kompira" dump_kompira
    get_cluster_status
    if $CLUSTER_CONFIGURED; then
        do_dump "HA" dump_HA
    fi

    cat <<EOF
###
### dump finished: $(date '+%Y-%m-%d %H:%M:%S')
###
EOF
}

init
dump 2>&1 | tee "$dumpdir/kompira_dump.log"
compress

