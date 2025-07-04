# Generated by Django 3.2.16 on 2023-06-19 06:11

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kompira', '0011_ldap_auth'),
    ]

    operations = [
        migrations.AlterField(
            model_name='incident',
            name='status',
            field=models.CharField(choices=[('OPENED', 'OPENED'), ('WORKING', 'WORKING'), ('CLOSED', 'CLOSED')], default='OPENED', max_length=7, verbose_name='Incident status'),
        ),
        migrations.AlterField(
            model_name='process',
            name='status',
            field=models.CharField(choices=[('NEW', 'NEW'), ('READY', 'READY'), ('RUNNING', 'RUNNING'), ('WAITING', 'WAITING'), ('ABORTED', 'ABORTED'), ('DONE', 'DONE')], default='NEW', max_length=7, verbose_name='Process status'),
        ),
        migrations.AlterField(
            model_name='task',
            name='status',
            field=models.CharField(choices=[('ONGOING', 'ONGOING'), ('WAITING', 'WAITING'), ('DONE', 'DONE'), ('CANCELED', 'CANCELED')], default='ONGOING', max_length=8, verbose_name='Task status'),
        ),
    ]
