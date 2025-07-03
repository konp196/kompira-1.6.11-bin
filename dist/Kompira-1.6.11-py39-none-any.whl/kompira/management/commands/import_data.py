# -*- coding: utf-8 -*-
import mimetypes
from django.core.management.base import BaseCommand, CommandError
from django.utils.encoding import smart_str

from kompira.core.importer import JSONFileImporter, ZipFileImporter
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation


class Command(BaseCommand):
    help = 'Import kompira model data from exported files.'

    def add_arguments(self, parser):
        parser.add_argument('filename', nargs='+', help='import filename')
        parser.add_argument('--user', dest='user', action='store', default='root', help='import as specified user')
        parser.add_argument('--directory', dest='origin_dir', action='store', default='/', help='path to import data')
        parser.add_argument('--force-mode', dest='force_mode', action='store_true', default=False, help='overwrite object forcibly')
        parser.add_argument('--overwrite-mode', dest='overwrite_mode', action='store_true', default=False, help='overwrite object')
        parser.add_argument('--owner-mode', dest='owner_mode', action='store_true', default=False, help='import object with owner info')
        parser.add_argument('--update-config-mode', dest='update_config_mode', action='store_true', default=False, help='update config data')
        parser.add_argument('--now-updated-mode', dest='now_updated_mode', action='store_true', default=False, help='set the current time to the update time')

    @audit_operation('object', interface='mng', type='import')
    def handle(self, *import_files, **options):
        import_files = options['filename']
        if not len(import_files):
            raise CommandError("No import file specified.")
        #
        # 1つめの引数のファイル名でフォーマットを判別する。
        # 異なる種類のフォーマットを混在させることはできない。
        #
        (mtype, _) = mimetypes.guess_type(import_files[0])
        for fname in import_files[1:]:
            if mimetypes.guess_type(fname)[0] != mtype:
                raise CommandError('Import failed: files of different formats cannot be mixed')
        try:
            if mtype == 'application/zip':
                importer = ZipFileImporter(**options)
            else:
                importer = JSONFileImporter(**options)
            importer.set_data_sources(*import_files)
            audit_bind(**importer.get_audit_context())
            audit_bind_detail(import_sources=import_files)
            importer.do_import()
            audit_bind(**importer.get_audit_result())
        except Exception as e:
            raise CommandError('Import failed: %s' % smart_str(e))
