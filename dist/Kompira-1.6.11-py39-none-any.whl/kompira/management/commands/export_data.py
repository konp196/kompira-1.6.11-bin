# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand, CommandError
from django.utils.encoding import smart_str
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation

from kompira.core.exporter import JSONFileExporter, ZipFileExporter


class Command(BaseCommand):
    help = 'Output kompira model data.'

    def add_arguments(self, parser):
        parser.add_argument('path', nargs='+', help='export object path')
        parser.add_argument('--directory', dest='origin_dir', action='store', default='/', help='export directory path')
        parser.add_argument('--virtual-mode', dest='virtual_mode', action='store_true', default=False, help='export including virtual objects')
        parser.add_argument('--zip-mode', dest='zip_mode', action='store_true', default=False, help='export in zip file format')
        parser.add_argument('--owner-mode', dest='owner_mode', action='store_true', default=False, help='export object owners')
        parser.add_argument('--without-attachments', dest='wo_attchs', action='store_true', default=False, help='export without attachment files')
        parser.add_argument('--file', dest='filename', action='store', help='output filename')

    @audit_operation('object', interface='mng', type='export')
    def handle(self, *args, **options):
        export_paths = options['path']
        if not len(export_paths):
            raise CommandError("No export paths file specified.")
        try:
            filename = options.pop('filename')
            if options.pop('zip_mode'):
                exporter_cls = ZipFileExporter
            else:
                exporter_cls = JSONFileExporter
            exporter = exporter_cls(filename_or_stream=filename, **options)
            exporter.set_export_paths(*export_paths)
            audit_bind(**exporter.get_audit_context())
            audit_bind_detail(export_paths=export_paths)
            exporter.do_export()
            audit_bind(**exporter.get_audit_result())
        except Exception as e:
            # from traceback import print_exc
            # print_exc()
            raise CommandError('Export failed: %s' % smart_str(e))
