# -*- coding: utf-8 -*-
import logging
import shutil
import subprocess
import os

from elevate import elevate
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from kompira.utils.db import reencrypt_all_fields
from kompira.utils.misc import is_root

logger = logging.getLogger('kompira')


class Command(BaseCommand):
    help = 'Change the master secret key for encrypted string data.'

    def add_arguments(self, parser):
        parser.add_argument('secret_key', nargs=1, type=str, help='new secret key')
        parser.add_argument('--no-backup', dest='backup', action='store_false', default=True, help='do not backup old secret key')
        parser.add_argument('--force', dest='force', action='store_true', default=False, help='forcibly reencrypt all fields')

    def handle(self, *args, **options):
        #
        # rootに昇格
        #
        elevate(graphical=False)
        #
        # パスワード長のチェック
        #
        secret_key = options['secret_key'][0]
        if len(secret_key) < settings.KOMPIRA_SECRET_KEY_MIN_LEN:
            raise CommandError(f'A secret key should be at least {settings.KOMPIRA_SECRET_KEY_MIN_LEN} characters')
        keyfile_path = settings.KOMPIRA_DB_KEYFILE_PATH
        try:
            #
            # マスターキーファイルをバックアップ
            #
            backup = options['backup']
            if backup:
                shutil.copyfile(keyfile_path, keyfile_path + '.bak')
            #
            # DBの暗号化フィールドを新しいパスワードで再暗号化する
            #
            reencrypt_all_fields(secret_key, options['force'])
        except Exception as e:
            raise CommandError('Failed to reencrypt fields: %s' % e)
        #
        # 新パスワードでファイルを更新
        #
        with open(keyfile_path, 'w') as keyfile:
            keyfile.write(secret_key)
        #
        # 冗長構成の場合は pcs property をセットする
        #   (reencrypt_all_fields 実行が成功すればアクティブ側である)
        #
        ret = subprocess.run(['yum', 'list', 'installed', 'pacemaker'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        cluster_configured = ret.returncode == 0
        if cluster_configured:
            ret = subprocess.run(['systemctl', 'is-active', 'pacemaker'])
            cluster_running = ret.returncode == 0
            if cluster_running:
                ret = subprocess.run(['pcs', 'property', 'set', f'pgsql-secret-key={secret_key.encode().hex()}', '--force'])
                if ret.returncode != 0:
                    self.stderr.write('Failed to set property pgsql-secret-key')
        self.stdout.write('''Master secret key was changed successfully.

[Notice]
  You should restart kompirad and httpd services to reload new master secret key file.''')
