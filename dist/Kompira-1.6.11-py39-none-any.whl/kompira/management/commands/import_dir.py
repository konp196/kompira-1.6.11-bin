# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand, CommandError
from django.utils.encoding import smart_str

from kompira.core.importer import DirectoryImporter
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation
from kompira_site.parameters import KOMPIRA_IMPORT_DIR_LINESEP, KOMPIRA_VALID_NEWLINES

class Command(BaseCommand):
    help = 'Import kompira model data from exported directories.'

    def add_arguments(self, parser):
        parser.add_argument('dirname', nargs='+', help='import directory name')
        parser.add_argument('--user', dest='user', action='store', default='root', help='import as specified user')
        parser.add_argument('--directory', dest='origin_dir', action='store', default='/', help='path to import data')
        parser.add_argument('--overwrite-mode', dest='overwrite_mode', action='store_true', default=False, help='overwrite object')
        parser.add_argument('--owner-mode', dest='owner_mode', action='store_true', default=False, help='import object with owner info')
        parser.add_argument('--update-config-mode', dest='update_config_mode', action='store_true', default=False, help='update config data')
        parser.add_argument('--now-updated-mode', dest='now_updated_mode', action='store_true', default=False, help='set the current time to the update time')
        parser.add_argument('--linesep', dest='linesep', choices=KOMPIRA_VALID_NEWLINES.keys(), default=KOMPIRA_IMPORT_DIR_LINESEP,
                            help=f'change line separator (text type files only), default: {KOMPIRA_IMPORT_DIR_LINESEP}')

    @audit_operation('object', interface='mng', type='import')
    def handle(self, *args, **options):
        import_dirs = options['dirname']
        options["newline"] = KOMPIRA_VALID_NEWLINES[options.pop("linesep")]
        try:
            importer = DirectoryImporter(**options)
            importer.set_data_sources(*import_dirs)
            audit_bind(**importer.get_audit_context())
            audit_bind_detail(import_sources=import_dirs)
            importer.do_import()
            audit_bind(**importer.get_audit_result())
        except Exception as e:
            raise CommandError('Import failed: %s' % smart_str(e))
