# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand, CommandError, OutputWrapper
from django.db import transaction
from django.utils.encoding import smart_str

from kompira.core.utils import json_dumps
from kompira.core.audit import audit_bind, audit_operation
from kompira.models.extends import Object, Channel, get_object
from kompira.utils.db import lock_object
from kompira.utils.stringify import stringify


class Command(BaseCommand):
    help = 'Peek (Get and NOT Delete) a message from Channel.'

    def add_arguments(self, parser):
        parser.add_argument('channel_path', help='channel path to peek')
        parser.add_argument('-i', '--index', dest='index', type=int, default=0, help='message index at message queue')
        parser.add_argument('-c', '--count', dest='count', type=int, default=1, help='count of messages to peek')
        parser.add_argument('--verbose', dest='verbose', action='store_true', default=False, help='print target object path and message count')

    @audit_operation('object', interface='mng', type='read')
    def handle(self, *args, **options):
        channel_path = options['channel_path']
        index = options['index']
        count = options['count']
        verbose = options['verbose']
        if verbose:
            verbose_out = OutputWrapper(self.stderr._out)
            verbose_out.style_func = self.style.SUCCESS
        audit_bind(target_path=channel_path)
        try:
            chan = get_object(channel_path)
            audit_bind(target_type=str(chan.type_object))
            if not isinstance(chan, Channel):
                raise CommandError('Specified path object is not channel.')
            with transaction.atomic():
                lock_object([chan], comment=u"peek_channel(%s)" % chan)
                message_count = chan.message_count
                if message_count == 0:
                    self.stderr.write('Specified channel has no messages.')
                    audit_bind(result='failed', reason='channel has no messages')
                    return
                elif index < 0:
                    if message_count + index < 0:
                        raise IndexError
                    index = message_count + index
                elif index >= message_count:
                    raise IndexError
                count = min(count, message_count - index)
                for n in range(count):
                    pre_count = chan.message_count
                    msgid, msg = chan.peek_message(index=index)
                    post_count = chan.message_count
                    if verbose:
                        if n > 0:
                            verbose_out.write("")
                        verbose_out.write("Target Channel: %s" % channel_path)
                        verbose_out.write("Message Count: %s -> %s" % (pre_count, post_count))
                        verbose_out.write("Message Index: %s" % index)
                        verbose_out.write("Message ID: %s" % msgid)
                        verbose_out.write("Message Type: %s" % type(msg).__name__)
                        verbose_out.write("")
                    if isinstance(msg, str):
                        text = msg
                    elif isinstance(msg, bytes):
                        try:
                            text = smart_str(msg)
                        except UnicodeDecodeError:
                            text = stringify(msg)
                    else:
                        try:
                            text = json_dumps(msg, ensure_ascii=False)
                        except Exception as e:
                            self.stderr.write('The message could not be JSON serialized.')
                            text = stringify(msg)
                    self.stdout.write(text)
                    index += 1
        except IndexError as e:
            self.stderr.write(f'Specified index({index}) is out of range.')
            audit_bind(result='failed', reason=f'index({index}) is out of range')
        except Object.DoesNotExist as e:
            raise CommandError('Specified path object does not exist.')
        except Exception as e:
            raise CommandError('Failed: %s' % smart_str(e))
