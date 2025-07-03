# -*- coding: utf-8 -*-
import logging

from django.core.management.base import BaseCommand, CommandError
from django.utils.encoding import smart_str

from kompira.models.extends import Jobflow
from kompira.core.audit import audit_bind_detail, audit_operation

logger = logging.getLogger('kompira')


class Command(BaseCommand):
    help = 'Compile jobflows.'

    def add_arguments(self, parser):
        parser.add_argument('path', nargs='*', help='jobflow path to compile')

    @audit_operation('object', interface='mng', type='compile', target_type=Jobflow.type_path())
    def handle(self, *args, **options):
        success = error = 0
        compile_paths = []
        paths = options['path']
        try:
            for path in paths or '/':
                compile_paths.append(path)
                audit_bind_detail(compile_paths=compile_paths)
                for jobflow in Jobflow.objects.all().descendant(path):
                    jobflow.compile()
                    if jobflow['executable']:
                        logger.info('%s: compiled successfully', jobflow.abspath)
                        success += 1
                    else:
                        errors = ''
                        for l, err in jobflow['errors'].items():
                            errors += "l.%s: %s; " % (l, err)
                        logger.warn('%s: compile error: %s', jobflow.abspath, errors)
                        error += 1
                    audit_bind_detail(compile_result={'success': success, 'error': error})
        except Exception as e:
            # import sys
            # from traceback import print_tb
            # _, _, tb = sys.exc_info()
            # print_tb(tb)
            raise CommandError('Compile failed: %s' % smart_str(e))
