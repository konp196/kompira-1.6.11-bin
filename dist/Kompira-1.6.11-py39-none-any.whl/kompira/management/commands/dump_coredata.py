# -*- coding: utf-8 -*-
import json
import sys
import logging
from datetime import datetime
from io import StringIO

from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from django.db import transaction

from kompira_common.utils import redirect_stdio
from kompira.models.core import DateTimeData
from kompira.utils.dateparse import parse_datetime

logger = logging.getLogger('kompira')


def dump_coredata(touch=False, touch_datetime=None):
    exclude = ('contenttypes', 'sessions', 'auth.Permission')
    datetime_fields = {
        'account.user': ('last_login',),
        'core.baseobject': ('created', 'updated',),
    }
    #
    # dump core data
    #
    sout = StringIO()
    with redirect_stdio(sout, sys.stderr):
        call_command('dumpdata', format='json', exclude=exclude)
    coredata = json.loads(sout.getvalue())
    #
    # touch datetime fields
    #
    if touch:
        if timezone.is_naive(touch_datetime):
            touch_datetime = timezone.make_aware(
                touch_datetime, timezone.get_current_timezone())
        touch_datetime_utc = touch_datetime.replace(microsecond=0).astimezone(timezone.utc)
        for data in coredata:
            model = data['model']
            fields = data['fields']
            for field in datetime_fields.get(model, ()):
                if field in fields:
                    fields[field] = DateTimeData.dumps(touch_datetime_utc)
    json.dump(coredata, sys.stdout)


class Command(BaseCommand):
    help = 'dump core data.'

    def add_arguments(self, parser):
        parser.add_argument('--touch', dest='touch', action='store_true', default=False, help='touch datetime fields')
        parser.add_argument('--touch-datetime', dest='touch_datetime', action='store', default=None, help='specify touch datetime')

    def handle(self, touch, touch_datetime, *args, **kwargs):
        if touch:
            if touch_datetime:
                touch_datetime = parse_datetime(touch_datetime)
                if not touch_datetime:
                    raise CommandError("invalid datetime format")
            else:
                touch_datetime = datetime.now()
        with transaction.atomic():
            dump_coredata(touch, touch_datetime)

