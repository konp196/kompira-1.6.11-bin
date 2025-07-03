# -*- coding: utf-8 -*-
import logging

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils.translation import gettext_lazy as _, activate

from kompira.models.account import User, Group, ProtectedGroup, ProtectedUser
from kompira.models.core import Field, StringData, GroupPermission, ProtectedObject
from kompira.models.extends import TypeObject, Directory
from kompira.utils.db import reset_sequence

logger = logging.getLogger('kompira')


def declare_type_fields(type_object, extend="", fieldNames=[], fieldDisplayNames=[], fieldTypes=[]):
    #
    # 型オブジェクトのフィールド定義
    #
    f_extend = Field(object=type_object, name="extend", display_name=_("Extend module"), type="String")
    f_extend.save(force_insert=True)
    f_fieldNames = Field(object=type_object, name="fieldNames", display_name=_("Field names"), type="Array")
    f_fieldNames.save(force_insert=True)
    f_fieldDisplayNames = Field(object=type_object, name="fieldDisplayNames", display_name=_("Field display names"), type="Array")
    f_fieldDisplayNames.save(force_insert=True)
    f_fieldTypes = Field(object=type_object, name="fieldTypes", display_name=_("Field types"), type="Array")
    f_fieldTypes.save(force_insert=True)
    StringData(field=f_extend, value=extend).save(force_insert=True)
    for value in fieldNames:
        StringData(field=f_fieldNames, value=value).save(force_insert=True)
    for value in fieldDisplayNames:
        StringData(field=f_fieldDisplayNames, value=value).save(force_insert=True)
    for value in fieldTypes:
        StringData(field=f_fieldTypes, value=value).save(force_insert=True)


def create_initial_data():
    #
    # 基本グループの作成
    #
    g_other = Group(name='other')
    g_other.save(force_insert=True)
    g_wheel = Group(name='wheel')
    g_wheel.save(force_insert=True)

    #
    # 基本ユーザの作成
    #
    u_admin = User(username='admin', is_staff=True, is_active=False)
    u_admin.set_password('admin')
    u_admin.save(force_insert=True)
    u_root = User(username='root', is_staff=False, is_active=True)
    u_root.set_password('root')
    u_root.save(force_insert=True)
    u_guest = User(username='guest', is_staff=False, is_active=True)
    u_guest.set_password('guest')
    u_guest.save(force_insert=True)

    #
    # 基本型オブジェクトの作成
    #
    t_typobj = TypeObject(id=1, display_name=_("TypeObject"), description=_("Type object of TypeObject"), abspath="/system/types/TypeObject", owner=u_root)
    t_typobj.type_object = t_typobj
    t_typobj.save(force_insert=True)

    t_directory = TypeObject(id=2, display_name=_("Directory"), description=_("Type object of Directory"), abspath="/system/types/Directory", owner=u_root, type_object=t_typobj)
    t_directory.save(force_insert=True)

    #
    # 基本ディレクトリ構成の作成
    #
    d_root = Directory(id=3, display_name=_("Root directory"), abspath="/", owner=u_root, type_object=t_directory)
    d_root.parent_object = d_root
    d_root.save(force_insert=True)
    d_system = Directory(id=4, display_name=_("System directory"), abspath="/system", owner=u_root, type_object=t_directory, parent_object=d_root)
    d_system.save(force_insert=True)
    d_system_types = Directory(id=5, display_name=_("System types directory"), abspath="/system/types", owner=u_root, type_object=t_directory, parent_object=d_system)
    d_system_types.save(force_insert=True)
    d_roothome = Directory(id=6, display_name="root", abspath="/root", owner=u_root, type_object=t_directory, parent_object=d_root)
    d_roothome.save(force_insert=True)
    d_userhome = Directory(id=7, display_name="home", abspath="/home", owner=u_root, type_object=t_directory, parent_object=d_root)
    d_userhome.save(force_insert=True)
    d_userhome_guest = Directory(id=8, display_name="guest", abspath="/home/guest", owner=u_guest, type_object=t_directory, parent_object=d_userhome)
    d_userhome_guest.save(force_insert=True)

    #
    # 型オブジェクトの親ディレクトリ情報更新
    #
    t_typobj.parent_object = d_system_types
    t_typobj.save(force_update=True)
    t_directory.parent_object = d_system_types
    t_directory.save(force_update=True)

    #
    # 基本ユーザのホームディレクトリ情報更新
    #
    u_root.home_directory = d_roothome
    u_root.save(force_update=True)
    u_guest.home_directory = d_userhome_guest
    u_guest.save(force_update=True)

    #
    # 基本グループパーミッション設定
    #
    GroupPermission(object=d_root, executable=False, readable=True, writable=False, owner=g_other).save(force_insert=True)
    GroupPermission(object=d_system, executable=False, readable=True, writable=False, owner=g_other).save(force_insert=True)
    GroupPermission(object=d_system_types, executable=False, readable=True, writable=False, owner=g_other).save(force_insert=True)
    GroupPermission(object=d_userhome, executable=False, readable=True, writable=False, owner=g_other).save(force_insert=True)

    #
    # 基本型オブジェクトのフィールド定義
    #
    declare_type_fields(t_typobj,
                        fieldNames=["extend", "fieldNames", "fieldDisplayNames", "fieldTypes"],
                        fieldDisplayNames=[_("Extend module"), _("Field names"), _("Field display names"), _("Field types")],
                        fieldTypes=["String", "Array", "Array", "Array"])
    declare_type_fields(t_directory,
                        fieldNames=["orderBy", "pageSize"],
                        fieldDisplayNames=[_("Sort order"), _("Page size")],
                        fieldTypes=["String", "Integer#{\"default\": 25, \"min_value\": 10, \"max_value\": 1000}"])

    #
    # オブジェクトのプロテクト設定
    #
    ProtectedGroup(group=g_other).save()
    ProtectedGroup(group=g_wheel).save()
    ProtectedUser(user=u_admin).save()
    ProtectedUser(user=u_root).save()
    ProtectedUser(user=u_guest).save()
    ProtectedObject(object=d_root).save()


class Command(BaseCommand):
    help = 'create initial data.'

    def add_arguments(self, parser):
        parser.add_argument('--locale', '-l', dest='locale',
            help='Locale to process (e.g. ja).')

    def handle(self, *paths, **options):
        locale = options.get('locale')
        if locale:
            activate(locale)
        with transaction.atomic():
            create_initial_data()
            reset_sequence('kompira')
        logger.info('initialized successfully')
