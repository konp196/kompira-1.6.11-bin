# -*- coding: utf-8 -*-
import logging
from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db.models import Count
from django.utils import timezone

from kompira.models.process import Process
from kompira.core.utils import json_dumps
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation
from kompira.utils.dateparse import parse_datetime

logger = logging.getLogger('kompira')


class Command(BaseCommand):
    help = 'Management kompira processes.'
    datetime_format = '%Y-%m-%d %H:%M:%S'
    datetime_isoformat = False
    columns = 'parent_id,pid,num_children,status,started_time,finished_time,elapsed_time,user,schedule,current_job'
    cell_separator = ' | '
    cell_width = dict(parent_id=9, pid=7, num_children=12, status=8, user=10, started_time=19, finished_time=19, elapsed_time=15, schedule=17, current_job=24, default=10)
    cell_format = dict(parent_id='>', pid='>', num_children='>',elapsed_time='>')
    defaults_for_action = {
        'list': {'status__in': Process.ACTIVE_STATES},
    }
    excludes_for_action = {
        'delete': {'status__in': Process.ACTIVE_STATES},
        'terminate': {'status__in': Process.FINISH_STATES},
        'suspend': {'status__in': Process.FINISH_STATES, 'suspended': True},
        'resume': {'status__in': Process.FINISH_STATES, 'suspended': False},
    }
    current_timezone = timezone.get_current_timezone()
    with_num_children = False

    def add_arguments(self, parser):
        parser.add_argument('-L', '--list', action='store_const', const='list', dest='action', default='list', help='print filtered processes')
        parser.add_argument('-C', '--count', action='store_const', const='count', dest='action', help='only print count')
        parser.add_argument('-D', '--delete', action='store_const', const='delete', dest='action', help='delete processes (only finish states)')
        parser.add_argument('-T', '--terminate', action='store_const', const='terminate', dest='action', help='terminate processes (only active states)')
        parser.add_argument('-S', '--suspend', action='store_const', const='suspend', dest='action', help='suspend processes (only active states)')
        parser.add_argument('-R', '--resume', action='store_const', const='resume', dest='action', help='resume processes (only active states)')
        parser.add_argument('-i', '--pid', action='append', type=int, help='filter by pid')
        parser.add_argument('-a', '--all', action='store_const', const=Process.ACTIVE_STATES + Process.FINISH_STATES, dest='status', default=[], help='clear status filter')
        parser.add_argument('--active', action='store_const', const=Process.ACTIVE_STATES, dest='status', help='filter by active states')
        parser.add_argument('--finish', action='store_const', const=Process.FINISH_STATES, dest='status', help='filter by finish states')
        parser.add_argument('--status', action='append', choices=Process.ACTIVE_STATES + Process.FINISH_STATES, help='filter by specified status')
        parser.add_argument('--suspended', action='store_true', default=None, help='filter by suspended status')
        parser.add_argument('--not-suspended', action='store_false', dest='suspended', help='filter by suspended status')
        parser.add_argument('--parent', type=int, action='append', help='filter by parent process id')
        parser.add_argument('--anyones-child', action='store_true', help='filter by anyones child')
        parser.add_argument('--min-children', type=int, help='filter by minimum number of children')
        parser.add_argument('--job', help='filter by started job flow path (regex)')
        parser.add_argument('--current-job', help='filter by current job flow path (regex)')
        parser.add_argument('--scheduled', action='store_true', default=None, help='filter by scheduled process')
        parser.add_argument('--not-scheduled', action='store_false', dest='scheduled', help='filter by not scheduled process')
        parser.add_argument('--scheduler-id', action='append', type=int, help='filter by scheduler id')
        parser.add_argument('--scheduler-name', help='filter by scheduler name')
        parser.add_argument('--invoked', action='store_true', default=None, help='filter by invoked process')
        parser.add_argument('--not-invoked', action='store_false', dest='invoked', help='filter by not invoked process')
        parser.add_argument('--invoker', action='append', help='filter by invoker object (abspath)')
        parser.add_argument('--invoker-type', action='append', help='filter by type-object (abspath) of invoker object')
        parser.add_argument('--user', action='append', help='filter by execute user')
        parser.add_argument('--started-since', help='filter by started datetime')
        parser.add_argument('--started-before', help='filter by started datetime')
        parser.add_argument('--finished-since', help='filter by finished datetime')
        parser.add_argument('--finished-before', help='filter by finished datetime')
        parser.add_argument('--elapsed-more', type=float, help='filter by elapsed_time (seconds)')
        parser.add_argument('--elapsed-less', type=float, help='filter by elapsed_time (seconds)')
        parser.add_argument('--console', help='filter by console output')
        parser.add_argument('--head', type=int)
        parser.add_argument('--tail', type=int)
        parser.add_argument('-r', '--reverse', action='store_const', const='-', default='', help='reverse order')
        parser.add_argument('--order', default='id', help='specify sort order')
        parser.add_argument('--format', choices=['table', 'json', 'export'], default='table', help='display format for list action')
        parser.add_argument('--json-ascii', action='store_true', default=False, help='ensure ascii when json output')
        parser.add_argument('--columns', default=self.columns)
        parser.add_argument('--no-header', action='store_true')
        parser.add_argument('--no-footer', action='store_true')
        parser.add_argument('--cell-separator', default=self.cell_separator)
        parser.add_argument('--datetime-format', default=self.datetime_format)
        parser.add_argument('--dry-run', action='store_true', help='dry-run mode')
        parser.add_argument('-y', '--noinput', action='store_false', dest='interactive', default=True,
                            help='not prompt the user for input of any kind.')

    def create_filters(self, **options):
        filters = {}
        # 親プロセスによるフィルタ
        if options['anyones_child']:
            filters['parent__isnull'] = False
        elif options['parent']:
            filters['parent_id__in'] = options['parent']
        else:
            filters['parent'] = None
        # 子プロセス数によるフィルタ
        if options['min_children']:
            filters['num_children__gte'] = options['min_children']
        # PID によるフィルタ
        if options['pid']:
            filters.update(id__in=options['pid'])
        # ステータスによるフィルタ
        if options['status'] == []:
            # アクションごとのデフォルトフィルタの適用
            defaults = self.defaults_for_action.get(options['action'], {})
            for key, val in defaults.items():
                filters[key] = val
        elif set(options['status']) == set(Process.ACTIVE_STATES + Process.FINISH_STATES):
            # 全ステータスが検索対象のときはフィルタ不要
            pass
        elif options['status']:
            # 指定したいずれかのステータスに対するフィルタの適用
            filters.update(status__in=options['status'])
        # サスペンド状態によるフィルタ
        if options['suspended'] is not None:
            filters.update(suspended=options['suspended'])
        # ジョブフローによるフィルタ
        if options['job']:
            filters.update(job__abspath__regex=options['job'])
        if options['current_job']:
            filters.update(current_job__abspath__regex=options['current_job'])
        # ユーザによるフィルタ
        if options['user']:
            filters.update(user__username__in=options['user'])
        # スケジューラによるフィルタ
        if options['scheduler_id']:
            filters.update(schedule__id__in=options['scheduler_id'])
        elif options['scheduler_name']:
            filters.update(schedule__name__regex=options['scheduler_name'])
        elif isinstance(options['scheduled'], bool):
            filters.update(schedule__isnull=not options['scheduled'])
        # 起動オブジェクトによるフィルタ
        if options['invoker']:
            filters.update(invoker__abspath__in=options['invoker'])
        elif options['invoker_type']:
            filters.update(invoker__type_object__abspath__in=options['invoker_type'])
        elif isinstance(options['invoked'], bool):
            filters.update(invoker__isnull=not options['invoked'])
        # 開始日時・終了日時のフィルタ
        if options['started_since']:
            filters.update(started_time__gte=parse_datetime(options['started_since']))
        if options['started_before']:
            filters.update(started_time__lt=parse_datetime(options['started_before']))
        if options['finished_since']:
            filters.update(finished_time__gte=parse_datetime(options['finished_since']))
        if options['finished_before']:
            filters.update(finished_time__lt=parse_datetime(options['finished_before']))
        # 経過時間によるフィルタ
        if options['elapsed_more']:
            filters.update(elapsed_time__gte=timedelta(seconds=options['elapsed_more']))
        if options['elapsed_less']:
            filters.update(elapsed_time__lt=timedelta(seconds=options['elapsed_less']))
        # コンソール出力によるフィルタ
        if options['console']:
            filters.update(console__contains=options['console'])
        return filters

    def get_queryset(self, **options):
        qs = Process.objects.all()
        # 子プロセス数を扱う場合は num_children を annotate しておく
        if options['min_children'] or 'num_children' in self.columns_list:
            self.with_num_children = True
            qs = qs.annotate(num_children=Count('children'))
        if options['verbosity'] > 1:
            print(f'# all processes: {qs.count()}')
        # フィルタ・除外・並び替えの適用
        filters = self.create_filters(**options)
        excludes = self.excludes_for_action.get(options['action'], {})
        order = options['reverse'] + options['order']
        if options['verbosity'] > 1:
            print(f'# filters: {filters}')
            print(f'# excludes: {excludes}')
            print(f'# order: {order}')
        qs = qs.filter(**filters)
        for key, val in excludes.items():
            qs = qs.exclude(**{key: val})
        qs = qs.order_by(order)
        if options['verbosity'] > 1:
            print(f'# filtered processes: {qs.count()}')
        # head / tail による件数絞込み
        offset, limit = None, None
        if options['head']:
            limit = max(0, options['head'])
        elif options['tail']:
            offset = max(0, qs.count() - options['tail'])
        qs = qs[offset:limit]
        if options['verbosity'] > 1:
            print(f'# slicing: {offset}:{limit}')
        audit_bind_detail(process_query={'filters': filters, 'excludes': excludes, 'order': order, 'offset': offset, 'limit': limit})
        return qs

    def aware_datetime(self, datetime):
        if datetime is None:
            pass
        elif timezone.is_aware(datetime):
            datetime = datetime.astimezone(self.current_timezone)
        else:
            datetime = timezone.make_aware(datetime, self.current_timezone)
        return datetime

    def datetime_tostring(self, datetime):
        if datetime is None:
            return str(datetime)
        elif self.datetime_isoformat:
            return datetime.isoformat()
        return datetime.strftime(self.datetime_format)

    def timedelta_tostring(self, td):
        if td >= timedelta(days=1):
            days = '{0} day{1}'.format(td.days, 's' if td.days>1 else '')
            mins = td.seconds // 60 % 60
            hours = td.seconds // 3600
            return '{0}, {1:02d}:{2:02d}'.format(days, hours, mins)
        return str(td)

    def proc_data(self, proc):
        data = {
            'parent_id': proc.parent_id,
            'pid': proc.pid,
            'status': proc.status + ('*' if proc.suspended else ''),
            'started_time': self.datetime_tostring(self.aware_datetime(proc.started_time)),
            'finished_time': self.datetime_tostring(self.aware_datetime(proc.finished_time)),
            'elapsed_time': self.timedelta_tostring(proc.elapsed_time),
            'user': proc.user,
            'job': proc.job,
            'current_job': proc.current_job,
            'schedule': proc.schedule,
        }
        if self.with_num_children:
            data['num_children'] = getattr(proc, 'num_children', None)
        return data

    def table_formatter(self, proc, header=False, footer=False):
        cell = []
        cell_separator = self.options['cell_separator']
        default_width = self.cell_width['default']
        if header:
            for key in self.columns_list:
                cell_width = self.cell_width.get(key, default_width)
                val = ('{0:^%s}' % cell_width).format(key)
                cell.append(val)
            header1 = cell_separator.join(cell)
            cell = []
            for key in self.columns_list:
                cell_width = self.cell_width.get(key, default_width)
                cell.append('-' * cell_width)
            header2 = cell_separator.join(cell)
            return header1 + "\n" + header2

        if proc:
            data = self.proc_data(proc)
            for key in self.columns_list:
                val = data[key]
                cell_width = self.cell_width.get(key, default_width)
                cell_format = self.cell_format.get(key, '')
                val = ('{0:%s%s}' % (cell_format, cell_width)).format(str(val))
                cell.append(val)
            return cell_separator.join(cell)

    def json_formatter(self, proc, header=False, footer=False):
        if proc:
            data = self.proc_data(proc)
            return json_dumps(data, ensure_ascii=self.options['json_ascii'])

    def export_formatter(self, proc, header=False, footer=False):
        if proc:
            return json_dumps(proc.dump_data(), ensure_ascii=self.options['json_ascii'], indent=2)

    def confirm_formatter(self, proc, header=False, footer=False):
        if proc:
            data = self.proc_data(proc)
            return "Process({pid}): status={status}, user={user}, current_job={current_job}".format(**data)

    def print_process(self, proc, formatter, header=False, footer=False):
        formatted = formatter(proc, header=header, footer=footer)
        if formatted is not None:
            print(formatted)

    def confirm_yesno(self, mesg, choices=('yes', 'no'), default=None):
        while True:
            confirm = input(mesg).lower()
            if confirm == '' and default:
                confirm = default
            if confirm in choices:
                break
        return confirm

    def confirm_action(self, action, proc):
        self.print_process(proc, self.confirm_formatter)
        return self.confirm_yesno("Are you sure you want to %s this? (yes/no): " % action)

    def count_processes(self, qs):
        count = qs.count()
        print(count)
        audit_bind_detail(process_count=count)
    count_processes.audit_type = 'read'

    def list_processes(self, qs):
        count = 0
        formatter = getattr(self, '{0}_formatter'.format(self.options['format']))
        if not self.options['no_header']:
            self.print_process(None, formatter, header=True)
        for p in qs:
            self.print_process(p, formatter)
            count += 1
            audit_bind_detail(process_listed=count)
        if not self.options['no_footer']:
            self.print_process(None, formatter, footer=True)
    list_processes.audit_type = 'read'

    def delete_processes(self, qs):
        processed = 0
        audit_bind_detail(process_deleted=processed)
        count = qs.count()
        if count == 0:
            logger.info("no target process for delete")
            return
        dry_run = self.options['dry_run']
        try:
            if self.options['head'] or self.options['tail']:
                logger.info("start deleting %s processes individually because head or tail specified.", count)
                for proc in qs:
                    if self.interactive:
                        if self.confirm_action('delete', proc) != 'yes':
                            continue
                    if not dry_run:
                        proc.delete()
                        processed += 1
                        audit_bind_detail(process_deleted=processed)
            else:
                logger.info("start deleting %s processes in bulk.", count)
                if self.interactive and self.confirm_yesno("Are you sure you want to delete them? (yes/no): ") != 'yes':
                    pass
                elif not dry_run:
                    bulk_deleted = qs.delete()
                    processed = count
                    audit_bind_detail(process_deleted=processed, bulk_deleted=bulk_deleted)
        finally:
            logger.info("finished deleting %s processes", processed)

    def terminate_processes(self, qs):
        self.control_engine('terminate_process', 'process_terminated', qs)

    def suspend_processes(self, qs):
        self.control_engine('suspend_process', 'process_suspended', qs)

    def resume_processes(self, qs):
        self.control_engine('resume_process', 'process_resumed', qs)

    def control_engine(self, method_name, audit_key, qs):
        from kompira_engine.engine_server import EngineServer
        action = self.options['action']
        count = qs.count()
        if count == 0:
            logger.info("no target process for %s", action)
            return
        proxy = EngineServer.get_proxy()
        dry_run = self.options['dry_run']
        control_method = getattr(proxy, method_name)
        logger.info("start %s for %s processes (via kompirad)", method_name, count)
        processed = 0
        try:
            for proc in qs:
                if self.interactive:
                    if self.confirm_action(action, proc) != 'yes':
                        continue
                logger.info("%s(%s)", method_name, proc.pid)
                if not dry_run:
                    control_method(proc.pid)
                    processed += 1
                    audit_bind_detail(**{audit_key: processed})
        finally:
            logger.info("finished %s for %s processes", method_name, processed)

    def remove_columns_list(self, key):
        try:
            self.columns_list.pop(self.columns_list.index(key))
        except ValueError:
            pass

    @audit_operation('process', interface='mng', target_path=Process.vroot_path)
    def handle(self, **options):
        import sys
        self.interactive = options.get('interactive')
        self.datetime_isoformat = options['format'] == 'json'
        self.datetime_format = options['datetime_format']
        self.columns_list = options['columns'].split(',')
        self.options = options

        if not (options['anyones_child'] or options['parent']):
            self.remove_columns_list('parent_id')
        if options['min_children'] is None:
            self.remove_columns_list('num_children')
        if not (options['scheduler_id'] or options['scheduler_name'] or options['scheduled'] is not False):
            self.remove_columns_list('schedule')
        try:
            qs = self.get_queryset(**self.options)
            action = options['action']
            action_method = getattr(self, f'{action}_processes')
            audit_bind(type=getattr(action_method, 'audit_type', action))
            action_method(qs)
        except KeyboardInterrupt as e:
            audit_bind(result='failed', reason=type(e).__name__)
        except Exception as e:
            if options['verbosity'] > 1:
                from traceback import print_tb
                _, _, tb = sys.exc_info()
                print_tb(tb)
            raise CommandError(f'failed: {e}')
