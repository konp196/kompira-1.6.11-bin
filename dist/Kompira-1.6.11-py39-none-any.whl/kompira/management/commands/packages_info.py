import logging
import os
import psutil
from jinja2 import Template
from prettytable import PrettyTable

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.core.exceptions import ObjectDoesNotExist
from django.utils import timezone

from kompira.models.account import get_user
from kompira.models.extends import TypeObject, Directory, get_object
from kompira.core.audit import audit_bind, audit_operation
from kompira.utils.packages_info import PipPackagesInfo, WebPackagesInfo
from kompira.utils.dateparse import parse_datetime

logger = logging.getLogger('kompira')


default_wiki_template = (r'''= Package list ({{ packages_info.type }})
{% if packages_info.collection %}
collected: {{ packages_info.collection.finished }}
{% endif %}

|=Name{% if packages_info.collection.with_requires %} (requires){% endif %}|=Installed|=Latest|=License|
{% for pkg in packages_info.packages -%}  
|{% if pkg.url %}[[{{ pkg.url }}|{{ pkg.name }}]]{% else %}{{ pkg.name }}{% endif %}{% if packages_info.collection.with_requires and pkg.require_version %} ({{ pkg.require_version|replace("~","~~") }}){% endif %}|{{ pkg.version }}|{{ pkg.latest_version }}|{{ pkg.license|replace("; ","\\\\") }}|
{% endfor %}

= Packge details
{% for pkg in packages_info.packages -%}  
== **{{ pkg.name }}**
{{ pkg.url }}
{% if pkg.description %}
=== Description:
{{ pkg.description }}
{% endif -%}
=== Version:
{% if packages_info.collection.with_requires and pkg.require_version -%}
* Required: {{ pkg.require_version|replace("~", "~~") }}
{% endif -%}
* Installed: {{ pkg.version }}
{% if pkg.latest_version -%}
* Latest: {{ pkg.latest_version }}
{% endif -%}
{% if pkg.license_text %}
=== License:
{{ '{{{' }}
{{ pkg.license_text|trim }}
{{ '}}}' }}
{% endif %}
{% endfor %}
''', 'Creole')


class Command(BaseCommand):
    help = 'Manage packages information.'
    username = 'root'
    wiki_dir_path = settings.KOMPIRA_PACKAGES_INFO_PATH
    wiki_typ_path = '/system/types/Wiki'
    packages_class = {
        'pip': PipPackagesInfo,
        'web': WebPackagesInfo,
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.wiki_templates = {}
        self.packages = {}

    def add_arguments(self, parser):
        parser.add_argument('--show', action='store_true', default=False, help='show packages information')
        parser.add_argument('--format', choices=['table', 'json', 'csv', 'wiki'], default='table', help='display format for show packages')
        parser.add_argument('--collect', action='store_true', default=False, help='collect packages information')
        parser.add_argument('--collect-latest', action='store_true', default=None, help='collect latest packages information')
        parser.add_argument('--no-collect-latest', action='store_false', dest='collect_latest', help='no collect collect packages information')
        parser.add_argument('--update', action='store_true', default=False, help=f'update WiKi objects on {self.wiki_dir_path}')
        parser.add_argument('--force', action='store_true', default=False, help='even if the WiKi object is up to date, it will be forced to update.')
        parser.add_argument('--without-pip', action='store_true', default=False, help='do no process pip pacakges')
        parser.add_argument('--without-web', action='store_true', default=False, help='do no process web pacakges')
        parser.add_argument('--proxy', help='specify a proxy to collect packages information')

    def check_execute_user(self, allowed_user='kompira', change_user='kompira'):
        """
        インストール環境では kompira ユーザでのみ実行可能とする
        """
        if not settings.BASE_DIR.startswith(settings.KOMPIRA_HOME):
            return
        username = psutil.Process().username()
        if username == allowed_user:
            pass
        elif username == 'root':
            # root で起動した場合は kompira ユーザになる（ファイルを kompira ユーザで保存するため）
            if change_user:
                pw = psutil.pwd.getpwnam(change_user)
                os.setgid(pw.pw_gid)
                os.setuid(pw.pw_uid)
                logger.info("packages_info: change user to %s", change_user)
        else:
            raise CommandError(f'Only the user "{allowed_user}" can run it.')

    @audit_operation('packages', interface='mng', type='read')
    def handle(self, *args, **options):
        for typ, klass in self.packages_class.items():
            if not options[f'without_{typ}']:
                self.packages[typ] = {'class': klass, 'info': None}
        show = True
        actions = []
        audit_bind(type='update', detail={'package_types': list(self.packages.keys())})
        try:
            if options['collect']:
                show = False
                actions.append('collect')
                self.check_execute_user()
                audit_bind(type='update', detail={'package_actions': actions})
                self.collect_packages_info(proxy=options['proxy'], collect_latest=options['collect_latest'])
            if options['update']:
                show = False
                actions.append('update')
                self.check_execute_user()
                audit_bind(type='update', detail={'package_actions': actions})
                self.update_wiki(force=options['force'])
        except Exception as e:
            raise CommandError('Failed to get packages information: %s' % e)
        if show or options['show']:
            actions.append('show')
            audit_bind(detail={'package_actions': actions})
            self.show_pacakges_info(options['format'])

    def load_packages_info(self):
        """
        収集済みのパッケージ情報をキャッシュから読み込む
        """
        for pkg in self.packages.values():
            if not pkg['info']:
                pkg['info'] = pkg['class'].load()

    def update_wiki(self, force=False):
        """
        パッケージ情報をもとに Wiki オブジェクトを更新する
        """
        self.user = get_user(self.username)
        self.wiki_dir = Directory.objects.get(abspath=self.wiki_dir_path)
        self.wiki_typ = TypeObject.objects.get(abspath=self.wiki_typ_path)
        self.load_packages_info()
        for typ, pkg in self.packages.items():
            self.create_wiki(typ, pkg['info'], force=force)

    def render_wiki(self, typ, packages_info):
        """
        テンプレートをもとに Wiki コンテンツをレンダリングする
        """
        wiki_template = self.wiki_templates.get(typ, default_wiki_template)
        rendered = Template(wiki_template[0]).render(packages_info=packages_info)
        return {'wikitext': rendered, 'style': wiki_template[1]}

    def create_wiki(self, typ, packages_info, force=False):
        """
        パッケージ情報をもとに Wiki オブジェクトを作成する

        - パッケージ情報に記録された収集日時より既存 Wiki オブジェクトが新しければスキップする
        - 作成した Wiki オブジェクトは書き込み権限をクリアして保護する
        """
        name = packages_info.get('type', typ)
        try:
            info_updated = parse_datetime(packages_info['collection']['finished'])
            wiki_obj = get_object(os.path.join(self.wiki_dir.abspath, name), get_virtual=False)
            if wiki_obj.type_object != self.wiki_typ:
                raise CommandError(f'An existing {wiki_obj} is not a Wiki object ({wiki_obj.type_object})')
            wiki_updated = timezone.localtime(wiki_obj.updated)
            if wiki_updated > info_updated:
                logger.info("packages_info: create_wiki: %s is up to date (%s > %s)", wiki_obj, wiki_updated, info_updated)
                if not force:
                    return
            wiki_obj.user_permissions[self.user] = {'readable': True, 'writable': True, 'executable': False}
        except (KeyError, ValueError) as e:
            logger.warning("packages_info: create_wiki: %r", e)
        except ObjectDoesNotExist:
            pass
        data = self.render_wiki(typ, packages_info)
        wiki_obj = self.wiki_dir.add(self.user, name, self.wiki_typ, data=data, overwrite=True)
        logger.info("packages_info: create_wiki: %s is updated", wiki_obj)
        wiki_obj.user_permissions[self.user] = {'readable': True, 'writable': False, 'executable': False}

    def collect_packages_info(self, **kwargs):
        """
        パッケージ情報を収集する

        - 収集したパッケージ情報は /var/opt/kompira/pacakges/ にキャッシュファイルとして保存される
        """
        for pkg in self.packages.values():
            pkg['class'].collect(**kwargs)
       
    def show_pacakges_info(self, format):
        """
        パッケージ情報をコンソールに表示する

        - 収集済みのパッケージ情報を指定したフォーマットで表示する
        """
        self.load_packages_info()
        if format == 'wiki':
            for typ, pkg in self.packages.items():
                data = self.render_wiki(typ, pkg['info'])
                self.stdout.write(data['wikitext'])
            return
        table = PrettyTable()
        table.field_names = ['Type', 'Name', 'Installed', 'Latest', 'License']
        for typ, pkg in self.packages.items():
            packages = pkg['info']['packages']
            table.add_rows([[typ, p['name'], p['version'], p.get('latest_version'), p.get('license')] for p in packages])
        if format == 'csv':
            self.stdout.write(table.get_csv_string())
        elif format == 'json':
            table.header = False
            self.stdout.write(table.get_json_string())
        else:
            table.align = 'l'
            self.stdout.write(table.get_string())
