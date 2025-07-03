#!/opt/kompira/bin/python
# -*- coding: utf-8 -*-
import argparse
import base64
import os
from os.path import abspath, dirname, isabs, join, relpath
import json
import sys
import tempfile
import zipfile
import django
from django.conf import settings
from django.core.exceptions import ObjectDoesNotExist
from django.core.files.storage import default_storage
from django.db.models import Q

try:
    from kompira_common import version
except ModuleNotFoundError:
    sys.path.append(join(dirname(abspath(__file__)), os.pardir))
    from kompira_common import version

CONFIG_TYPE_PATH = '/system/types/Config'


def setup(kompira_settings):
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", kompira_settings)
    settings.LOGGING['handlers']['kompira'] = {
        'level': 'INFO',
        'class': 'logging.StreamHandler',
    }
    django.setup()


def check_version():
    (_major, minor, release, _sub, _patch) = version._VERSION
    # Ver.1.5 以上、 Ver.1.6.3 以下が対象
    if minor < 5 or (minor == 6 and release >= 4):
        print("""Not supported Kompira version: {0}
  This tool works with Kompira versions 1.5 to 1.6.3.""".format(version.VERSION))
        exit(1)
    return version.BRANCH


def make_data(fval):
    if not fval['name']:
        return
    file_path = default_storage.path(fval['path'])
    file_name = fval['name']
    return {'file_name': file_name, 'file_path': file_path}


def append_obj(obj_dic, obj, fname, ftype, fval):
    obj_data = obj_dic.setdefault(obj.abspath, {'typepath': obj.type_object.abspath, 'fields': {}})
    field_data = {'type': ftype, 'value': None}

    if ftype == 'File':
        if fval['path']:
            field_data['value'] = make_data(fval)
    elif ftype == 'Dictionary<File>':
        val_dic = field_data['value'] = {}
        for key, val in fval.items():
            if val:
                val_dic[key] = make_data(val)
            else:
                val_dic[key] = None
    elif ftype == 'Array<File>':
        val_list = field_data['value'] = []
        for val in fval:
            val_list.append(make_data(val))
    else:
        assert False  # 値は File/Dictionary<File>/Array<File> のいずれか

    if field_data['value']:
        obj_data['fields'][fname] = field_data


def convert_file(value, file_zip):
    if value is None:
        return

    result = {'name': value['file_name']}
    file_data = None
    try:
        if file_zip:
            file_data_key = 'data_ref'
            file_data = relpath(value['file_path'], settings.MEDIA_ROOT)
            file_zip.write(value['file_path'], arcname=file_data)
        else:
            file_data_key = 'data'
            with open(value['file_path'], 'rb') as f:
                file_data = base64.b64encode(f.read()).decode()
    except (IOError, OSError):
        sys.stderr.write('[WARNING] failed to open file: {0}\n'.format(value['file_path']))
    result[file_data_key] = file_data
    return result


def convert_field(value, file_zip):
    if value['type'] == 'File':
        return convert_file(value['value'], file_zip)
    elif value['type'] == 'Dictionary<File>':
        ret = {}
        for key, val in value['value'].items():
            ret[key] = convert_file(val, file_zip)
        return ret
    elif value['type'] == 'Array<File>':
        ret = []
        for val in value['value']:
            ret.append(convert_file(val, file_zip))
        return ret
    else:
        assert False  # 値は File/Dictionary<File>/Array<File> のいずれか


def convert_data(obj_path, type_path, obj_data, file_zip):
    parent_path = dirname(obj_path)
    data = {
        'objpath': obj_path,
        'typepath': type_path,
        'fields': {},
        'parent_object': parent_path
    }
    if type_path == CONFIG_TYPE_PATH:
        data['data'] = {}
    for fname, value in obj_data.items():
        fvalue = convert_field(value, file_zip)
        #
        # Config型オブジェクトの場合、data に格納する
        #
        # (備考) Config 型自体のフィールドに添付ファイルフィールドは含まれていないため、
        #        fields に格納すべきデータは無いはずなので、問題無い
        #
        if type_path == CONFIG_TYPE_PATH:
            data['data'][fname.replace('_data_', '', 1)] = fvalue
        else:
            data['fields'][fname] = fvalue
    return data


class JSONEmitter(object):
    DEFAULT_NAME = 'kompira_export_files.json'

    def __init__(self, filename):
        self._filename = filename or self.DEFAULT_NAME
        self._json_file = open(self._filename, 'w')
        self._json_file.write('[')
        self._first_time = True

    def emit(self, data):
        if self._first_time:
            self._first_time = False
        else:
            self._json_file.write(',\n')
        json.dump(data, self._json_file, indent=2)

    def close(self):
        self._json_file.write(']')
        self._json_file.close()

    @property
    def zip_file(self):
        return None

    @property
    def filename(self):
        self._filename


class ZipEmitter(JSONEmitter):
    EXPORT_JSON_FILENAME = 'kompira_export.json'
    DEFAULT_NAME = 'kompira_export_files.zip'

    def __init__(self, filename):
        self._filename = filename or self.DEFAULT_NAME
        self._zip_file = zipfile.ZipFile(self._filename, 'w', allowZip64=True, compression=zipfile.ZIP_DEFLATED)
        self._json_file = tempfile.NamedTemporaryFile(mode='w')
        self._json_file.write('[')
        self._first_time = True

    def close(self):
        self._json_file.write(']')
        self._json_file.flush()
        self._zip_file.write(self._json_file.name, arcname=self.EXPORT_JSON_FILENAME)
        self._json_file.close()
        self._zip_file.close()

    @property
    def zip_file(self):
        return self._zip_file


def check_subdir(subdir):
    if subdir is None or subdir == '/':
        return ''  # 後で suffix '/' 付きでフィルタされるため、ここでは空文字列を返す
    elif not isabs(subdir):
        subdir = join('/', subdir)
    try:
        dir_or_table = get_object(subdir)
    except ObjectDoesNotExist:
        print("Directory or table '{0}' not found".format(subdir))
        exit(1)
    if not dir_or_table.is_dir:
        print("'{0}' is not a directory or a table".format(subdir))
        exit(1)
    return dir_or_table.abspath


def main(query, args):
    subdir = check_subdir(args.directory)
    obj_dic = {}
    for f in Field.objects.filter(query, object__abspath__startswith=subdir + '/'):
        if not f.value: continue
        append_obj(obj_dic, f.object, f.name, f.type, f.value)

    if args.json_mode:
        emitter_cls = JSONEmitter
    else:
        emitter_cls = ZipEmitter
    emitter = emitter_cls(args.filename)
    for obj_path, obj_data in obj_dic.items():
        if obj_data['fields']:
            data = convert_data(obj_path, obj_data['typepath'], obj_data['fields'], emitter.zip_file)
            emitter.emit(data)
    emitter.close()
    sys.stderr.write('Output file: {0}\n'.format(emitter._filename))


parser = argparse.ArgumentParser(description='Convert attachment files.')
parser.add_argument('--directory', help='target directory or table')
parser.add_argument('--filename', help='specify file name to output')
parser.add_argument('--json-mode', action='store_true', dest='json_mode', help='file data is output embedded in JSON')

if __name__ == '__main__':
    ret = check_version()

    #
    # elevate が導入されていれば root 権限に昇格する(v.1.6.2 以降)
    #
    try:
        from elevate import elevate
        elevate(graphical=False)
    except ImportError:
        pass

    if ret == '1.5':
        setup('kompira.settings')
        from kompira.extends.models import get_object
        from kompira.core.models import Field
        query = Q(type='File')
    else:
        setup('kompira_site.settings')
        from kompira.models.extends import get_object
        from kompira.models.core import Field
        query = Q(type='File') | Q(type='Array<File>') | Q(type='Dictionary<File>')

    args = parser.parse_args()
    main(query, args)
