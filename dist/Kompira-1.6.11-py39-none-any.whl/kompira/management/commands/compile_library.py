# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand, CommandError
from django.utils.encoding import smart_str

from kompira.models.extends import Object, Library
from kompira.core.audit import audit_bind_detail, audit_operation


class Command(BaseCommand):
    help = 'Compile libraries.'

    def add_arguments(self, parser):
        parser.add_argument('path', nargs='*', help='library path to compile')

    @audit_operation('object', interface='mng', type='compile', target_type=Library.type_path())
    def handle(self, *paths, **options):
        paths = list(map(smart_str, options['path'] or ['/']))
        audit_bind_detail(compile_paths=paths)
        objs = []
        for path in paths:
            try:
                objs.append(Object.objects.get(abspath=path))
            except Object.DoesNotExist:
                raise CommandError('Object does not exist: %s' % path)
        try:
            success, error, skip = Library.iter_compile(objs, recursive=True)
            audit_bind_detail(compile_result={'success': success, 'error': error})
            Library.refresh_libraries()
        except Exception as e:
            raise CommandError('Compile failed: %s' % smart_str(e))
