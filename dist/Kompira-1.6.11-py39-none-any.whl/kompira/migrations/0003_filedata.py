# Generated by Django 3.0.5 on 2020-12-17 13:18
import logging
import json
import django.contrib.postgres.fields.jsonb
import django.db.models.deletion
from django.db import migrations, models, connection

logger = logging.getLogger('kompira')


#
# Ver1.6.1以前でFileフィールドがあれば、FileDataに移行する
#
def migrate_file_field(apps, schema_editor):
    from kompira.models.core import Field, StringData

    cursor = connection.cursor()
    for field in Field.objects.filter(type='File'):
        try:
            name = StringData.objects.filter(field__id=field.id, key='name').get()
            path = StringData.objects.filter(field__id=field.id, key='path').get()
            if path.value:
                field_data = {'name': name.value, 'path': path.value}
            else:
                field_data = {'name': None, 'path': None}
            cursor.execute('INSERT INTO kompira_filedata (field_id, value) VALUES (%s, %s)', (field.id, json.dumps(field_data)))
            name.delete()
            path.delete()
        except StringData.DoesNotExist:
            logger.warning("[Migration] failed to migrate file data: %s", field)


class Migration(migrations.Migration):

    dependencies = [
        ('kompira', '0002_encryptedstringdata'),
    ]

    operations = [
        migrations.CreateModel(
            name='FileData',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('key', models.CharField(max_length=1024, null=True, verbose_name='key')),
                ('value', django.contrib.postgres.fields.jsonb.JSONField(null=True, verbose_name='value')),
                ('field', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='filedata_data', to='kompira.Field')),
            ],
            options={
                'abstract': False,
                'unique_together': {('key', 'field')},
                'index_together': {('field', 'id')},
            },
        ),
        migrations.RunPython(migrate_file_field)
    ]
