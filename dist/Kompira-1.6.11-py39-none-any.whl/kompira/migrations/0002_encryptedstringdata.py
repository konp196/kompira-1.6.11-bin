# Generated by Django 3.0.5 on 2020-10-01 05:39

from django.db import migrations, models
import django.db.models.deletion
import pgcrypto.fields


#
# Ver1.6.1以前でStringDataのパスワードフィールドがあれば、EncryptedStringDataに移行する
#
def migrate_password_field(apps, schema_editor):
    from kompira.models.core import StringData

    for entry in StringData.objects.filter(field__type='Password'):
        password = entry.value
        entry.field.value = password
        entry.delete()


class Migration(migrations.Migration):

    dependencies = [
        ('kompira', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='EncryptedStringData',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('key', models.CharField(max_length=1024, null=True, verbose_name='key')),
                ('value', pgcrypto.fields.TextPGPSymmetricKeyField(blank=True, default='', verbose_name='value')),
                ('field', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='encryptedstringdata_data', to='kompira.Field')),
            ],
            options={
                'abstract': False,
                'unique_together': {('key', 'field')},
                'index_together': {('field', 'id')},
            },
        ),
        migrations.RunPython(migrate_password_field)
    ]

