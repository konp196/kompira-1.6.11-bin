# -*- coding: utf-8 -*-
from django.core.management.base import BaseCommand, CommandError
from kompira.models.extends import License
from kompira.core.audit import audit_bind, audit_bind_detail, audit_operation
from kompira_common.license import LicenseError


class Command(BaseCommand):
    help = 'Show kompira license information.'

    @audit_operation('object', interface='mng')
    def handle(self, *args, **options):
        try:
            audit_bind(target_path=License.PATH, type='read')
            self.license = License.objects.get(abspath=License.PATH)
            audit_bind(target_type=self.license.type_object)
            audit_bind_detail(license_id=self.license.license_info.license_id)
            info = self.get_license_info()
            self.stdout.write('*** Kompira License Information ***')
            self.stdout.write(info)
            self.license.check_license()
            if not self.license.license_info.signature:
                self.stdout.write('\nKompira is running with temporary license.')
        except LicenseError as e:
            raise CommandError('License error: %s' % e)
        except License.DoesNotExist:
            raise CommandError('License object is missing: %s' % License.PATH)
        except Exception as e:
            raise CommandError('Failed to get license information: %s' % e)

    def get_license_info(self):
        linfo = self.license.license_info
        lmngr = self.license.license_manager
        nodes = '%s' % (lmngr.node_count or 0)
        limits = linfo['limits']['node']
        if limits:
            nodes += ' / %s' % limits
        jobflows = '%s' % lmngr.jobflow_count
        limits = linfo['limits']['instance'].get('Jobflow')
        if limits:
            jobflows += ' / %s' % limits
        scripts  = '%s' % lmngr.script_count
        limits = linfo['limits']['instance'].get('ScriptJob')
        if limits:
            scripts += ' / %s' % limits
        data = [('License ID',      linfo.license_id),
                ('Edition',         linfo.edition),
                ('Hardware ID',     linfo.hardware_id),
                ('Expire date',     linfo.expire_date),
                ('The number of registered nodes',      nodes),
                ('The number of registered jobflows',   jobflows),
                ('The number of registered scripts',    scripts),
                ('Licensee',        linfo.licensee),
                ('Signature',       linfo.signature)]
        return '\n'.join(['%s:\t%s' % t for t in data])
