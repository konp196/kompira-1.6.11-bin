# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand, CommandError
from django.utils.encoding import smart_str

from kompira.core.exporter import DirectoryExporter
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation
from kompira_site.parameters import KOMPIRA_VALID_NEWLINES, KOMPIRA_EXPORT_DIR_LINESEP

class Command(BaseCommand):
    help = 'Output kompira model data to directory.'

    def add_arguments(self, parser):
        parser.add_argument('path', nargs='+', help='export object path')
        parser.add_argument('--directory', dest='origin_dir', action='store', default='/', help='export directory path')
        parser.add_argument('--property-mode', dest='property_mode', action='store_true', default=False, help='export with property info')
        parser.add_argument('--datetime-mode', dest='datetime_mode', action='store_true', default=False, help='export with created and updated')
        parser.add_argument('--without-attachments', dest='wo_attchs', action='store_true', default=False, help='export without attachment files')
        parser.add_argument('--inline-attachments', dest='inl_attchs', action='store_true', default=False, help='export attachment files embedded in yaml')
        parser.add_argument('--current', dest='current_dir', action='store', default='.', help='change current directory')
        parser.add_argument('--linesep', dest='linesep', choices=KOMPIRA_VALID_NEWLINES.keys(), default=KOMPIRA_EXPORT_DIR_LINESEP,
                            help=f'change line separator of output files(text types only), default: {KOMPIRA_EXPORT_DIR_LINESEP}')

    @audit_operation('object', interface='mng', type='export')
    def handle(self, *args, **options):
        export_paths = options['path']
        if not len(export_paths):
            raise CommandError("No export paths file specified.")
        options["newline"] = KOMPIRA_VALID_NEWLINES[options.pop("linesep")]
        try:
            exporter = DirectoryExporter(**options)
            exporter.set_export_paths(*export_paths)
            audit_bind(**exporter.get_audit_context())
            audit_bind_detail(export_paths=export_paths)
            exporter.do_export()
            audit_bind(**exporter.get_audit_result())
        except Exception as e:
            # from traceback import print_exc
            # print_exc()
            raise CommandError('Export failed: %s' % smart_str(e))
