# -*- coding: utf-8 -*-
import os
import os.path
import pwd
import shutil
import stat

from elevate import elevate
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from kompira.models.extends import License
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation
from kompira_common.license import LicenseError


class Command(BaseCommand):
    help = 'update kompira license file.'

    def add_arguments(self, parser):
        parser.add_argument('license_file', nargs=1, help='path of the license file')
        parser.add_argument('--no-backup', dest='nobackup_mode', action='store_true', default=False, help='skip to backup the old license file')
        parser.add_argument('--force', dest='force_mode', action='store_true', default=False, help='forcibly update')

    @audit_operation('object', interface='mng')
    def handle(self, *args, **options):
        license_path = options['license_file'][0]
        force_mode = options['force_mode']
        nobackup_mode = options['nobackup_mode']
        #
        # rootに昇格
        #
        elevate(graphical=False)
        audit_bind(target_path=License.PATH, type='update')
        audit_bind_detail(license_path=license_path)
        try:
            with open(license_path) as lic_file:
                lic_data = lic_file.read()
                linfo = License.load_license_data(lic_data)
        except (LicenseError, OSError) as e:
            raise CommandError(f"Failed to read license file '{license_path}': %s" % e)
        #
        # 有効期限やハードウェアIDの検査
        #
        try:
            License.check_license_info(linfo)
        except LicenseError as e:
            if force_mode:
                self.stderr.write(self.style.WARNING(f'[WARNING] license file is invalid: {e}'))
            else:
                raise CommandError('Failed to check license: %s' % e)
        #
        # バックアップ
        #
        if not nobackup_mode and os.path.isfile(License.license_file_path):
            try:
                shutil.copyfile(License.license_file_path, License.license_file_path + '.bak')
            except OSError as e:
                raise CommandError('Failed to backup license file: %s' % e)
        #
        # ライセンスファイルのコピー
        #
        try:
            License.save_license_data(lic_data, reraise=True)
        except OSError as e:
            raise CommandError('Failed to update license: %s' % e)
        try:
            # owner を kompira:kompira に変更する
            # permission を 664 に変更する
            user = pwd.getpwnam(settings.KOMPIRA_USER)
            os.chown(License.license_file_path, user.pw_uid, user.pw_gid)
            os.chmod(License.license_file_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IWGRP | stat.S_IROTH)
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'[WARNING] Failed to change license file owner or permissions: {e}'))
        #
        # 監査ログに記録する
        #
        license = License.objects.get(abspath=License.PATH)
        linfo = license.license_info
        audit_bind(target_type=str(license.type_object))
        audit_bind_detail(license_id=linfo.license_id)
        self.stdout.write(self.style.SUCCESS(f'License file has been successfully updated: {linfo.license_id}'))
