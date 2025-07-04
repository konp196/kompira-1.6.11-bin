"""
Django settings for kompira_site project.

Generated by 'django-admin startproject' using Django 3.0.5.

For more information on this file, see
https://docs.djangoproject.com/en/3.0/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/3.0/ref/settings/
"""

import ldap
import multiprocessing
import os
import sys
import structlog
from psutil import Process

from django.contrib.messages import constants as message_constants

import kompira.core.audit
from kompira.core.utils import _encode
from kompira_common.setup_logger import SIMPLE_FORMAT, DEFAULT_FORMAT, VERBOSE_FORMAT
from kompira_common.utils import system_timezone
from .parameters import *

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
# Kompira settings
KOMPIRA_HOME = '/opt/kompira'
KOMPIRA_VAR_HOME = '/var/opt/kompira'
KOMPIRA_LICENSE_FILE_PATH = os.path.join(KOMPIRA_VAR_HOME, 'kompira.lic')
KOMPIRA_REPOSITORY_PATH = os.path.join(KOMPIRA_VAR_HOME, 'repository')
KOMPIRA_DB_KEYFILE_PATH = os.path.join(KOMPIRA_VAR_HOME, '.secret_key')
KOMPIRA_ROOT = u''
KOMPIRA_SIDE_PATH = ['/system', '/user', '/home']
KOMPIRA_MENU_PATH = ['/task', '/incident', '/process', '/scheduler']
KOMPIRA_CONF_PATH = ['/config/user', '/config/group', '/config/realms', '/system/config', '/config/license']
KOMPIRA_HOME_PATH = '/home'
KOMPIRA_ENGINE_PORT = 5593
KOMPIRA_ENGINE_SERVER = '127.0.0.1'
KOMPIRA_AMQP = {
    'server': 'localhost',
    'port': 5672,
    'user': 'guest',
    'password': 'guest',
    'ssl': False,
    'timeout': 5,
    'max_retry': 3,
    'retry_interval': 30,
}
KOMPIRA_CODE_CACHE_SIZE = 1024

# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/3.0/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'q=om1k-q8sk5u&%_r7v)zjd%9o4*_ty0**hyd2w2rqc8((9+4*'

try:
    with open(KOMPIRA_DB_KEYFILE_PATH) as keyfile:
        PGCRYPTO_KEY = keyfile.read().strip()
except Exception as e:
    #
    # [TODO]
    # キーファイルが存在しない場合、起動時にエラーメッセージを出力する
    #
    # 現状、パスワードフィールド更新時には、画面上に
    # update できません: 'Settings' object has no attribute 'PGCRYPTO_KEY' (AttributeError)
    # というエラーメッセージは表示される
    #
    pass

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False

ALLOWED_HOSTS = ['*']

#SESSION_EXPIRE_AT_BROWSER_CLOSE = True  # ブラウザを閉じるとログインセッションをクローズする
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': 'unix:/var/run/memcached/memcached.sock',
    },
    'select2': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': 'unix:/var/run/memcached/memcached.sock',
        'TIMEOUT': 3600, # 1 hour
    }
}

# Application definition

INSTALLED_APPS = [
    'pgcrypto',
    'kompira.apps.KompiraConfig',
    'kompira_engine.apps.KompiraEngineConfig',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.postgres',
    'django_select2',
    'django_filters',
    'axes',
    'rest_framework',
    'rest_framework.authtoken',
    'tempus_dominus',
]

MIDDLEWARE = [
    'kompira.core.middleware.HandleExceptionMiddleware',
    'kompira.core.middleware.CheckDbMiddleware',
    'kompira.core.middleware.NormalizePathMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'axes.middleware.AxesMiddleware',
]

ROOT_URLCONF = 'kompira_site.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.template.context_processors.i18n',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                "kompira.core.context_processors.kompira",
            ],
        },
    },
]

WSGI_APPLICATION = 'kompira_site.wsgi.application'


# Database
# https://docs.djangoproject.com/en/3.0/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'kompira',
        'USER': 'kompira',                      # Not used with sqlite3.
        'PASSWORD': '',                         # Not used with sqlite3.
        'HOST': '/var/run/postgresql',
        'PORT': '',
    }
}

# Password validation
# https://docs.djangoproject.com/en/3.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

# Internationalization
# https://docs.djangoproject.com/en/3.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = system_timezone()

AUTH_USER_MODEL = 'kompira.User'

USE_I18N = True

USE_L10N = True

USE_TZ = True

FORMAT_MODULE_PATH = 'kompira.locale'

from django.conf.global_settings import DATETIME_INPUT_FORMATS, DATE_INPUT_FORMATS
DATETIME_INPUT_FORMATS += ('%Y/%m/%d %H:%M:%S',)
DATE_INPUT_FORMATS += ('%Y/%m/%d',)

LOCALE_PATHS = (
    os.path.join(BASE_DIR, 'kompira/locale'),
)

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/3.0/howto/static-files/

STATIC_URL = '/.static/'

# Absolute path to the directory static files should be collected to.
# Don't put anything in this directory yourself; store your static files
# in apps' "static/" subdirectories and in STATICFILES_DIRS.
# Example: "/home/media/media.lawrence.com/static/"
STATIC_ROOT = os.path.join(KOMPIRA_VAR_HOME, 'html/')

STATICFILES_STORAGE = 'django_flexible_manifest_staticfiles.storages.FlexibleManifestStaticFilesStorage'
STATICFILES_VERSIONED_EXCLUDE = ['kompira/img/.*$']

# Absolute filesystem path to the directory that will hold user-uploaded files.
# Example: "/home/media/media.lawrence.com/media/"
MEDIA_ROOT = os.path.join(KOMPIRA_VAR_HOME, 'upload/')

# Absolute path to the directory packages information should be collected to.
KOMPIRA_PACKAGES_INFO_CACAHE_ROOT = os.path.join(KOMPIRA_VAR_HOME, 'packages/')
KOMPIRA_PACKAGES_INFO_PATH = '/system/packages'

# URL that handles the media served from MEDIA_ROOT. Make sure to use a
# trailing slash.
# Examples: "http://media.lawrence.com/media/", "http://example.com/media/"
MEDIA_URL = '/.upload/'

LOGIN_URL = '/.login'
MESSAGE_STORAGE = 'kompira.utils.messages.SessionDedupStorage'
MESSAGE_TAGS = {
    message_constants.DEBUG: 'debug',
    message_constants.INFO: 'info',
    message_constants.SUCCESS: 'success',
    message_constants.WARNING: 'warning',
    message_constants.ERROR: 'danger',     # bootstrapアラートのために修正
}

# Sending email
# https://docs.djangoproject.com/en/3.0/topics/email/

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'

# default options for json_dumps, etc.
DEFAULT_JSON_DUMP_OPTS = {
    'ensure_ascii': True,
    'indent': None,
}

# default options for json_loads, KompiraJSONParser, etc.
DEFAULT_JSON_LOAD_OPTS = {
    'strict': False,
}

#
# for REST framework
#
REST_FRAMEWORK = {
    'EXCEPTION_HANDLER': 'kompira.views.core.api_exception_handler',
    'DEFAULT_RENDERER_CLASSES': (
        'kompira.core.renderers.KompiraJSONRenderer',
        'rest_framework.renderers.BrowsableAPIRenderer',
    ),
    'DEFAULT_PARSER_CLASSES': [
        'kompira.core.parsers.KompiraJSONParser',
        'kompira.core.parsers.SimpleTextParser',
        'rest_framework.parsers.FormParser',
        'rest_framework.parsers.MultiPartParser'
    ],
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'kompira.core.authentication.TokenAuthSupportQueryString',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
    ),
    'ORDERING_PARAM': 'order_by',
}

#
# Django authentication
#
AUTHENTICATION_BACKENDS = [
    # 記述した順番で authenticate() メソッドが呼び出される
    'axes.backends.AxesBackend',
    "kompira.utils.ldap_backend.KompiraLDAPBackend",
    "kompira.utils.model_backend.KompiraModelBackend",
]

AUTH_LDAP_GLOBAL_OPTIONS = {
    ldap.OPT_X_TLS_REQUIRE_CERT: ldap.OPT_X_TLS_NEVER,
}
AUTH_LDAP_CONNECTION_OPTIONS = {
    ldap.OPT_NETWORK_TIMEOUT: 10.0,
}

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'simple': {
            'format': SIMPLE_FORMAT
        },
        'default': {
            'format': DEFAULT_FORMAT
        },
        'verbose': {
            'format': VERBOSE_FORMAT
        },
        'json': {
            '()': structlog.stdlib.ProcessorFormatter,
            'processor': structlog.processors.JSONRenderer(default=_encode, ensure_ascii=False),
        },
    },
    'handlers': {
        'mail_admins': {
            'level': 'ERROR',
            'filters': ['require_debug_false'],
            'class': 'django.utils.log.AdminEmailHandler'
        },
        'kompira': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'audit': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'json',
        },
    },
    'loggers': {
        'django.request': {
            'handlers': ['mail_admins'],
            'level': 'ERROR',
            'propagate': True,
        },
        'kompira': {
            'handlers': ['kompira'],
            'level': 'INFO',
            'propagate': False,
        },
        'axes': {
            'handlers': ['kompira'],
            'level': 'INFO',
            'propagate': False,
        },
        'audit': {
            'handlers': ['audit'],
            'level': 'INFO',
            'propagate': False,
        },
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse'
        }
    },
}

#
# structlog の設定
#
structlog.configure(
    processors=[
        structlog.threadlocal.merge_threadlocal,
        kompira.core.audit.add_execution_info,
        kompira.core.audit.add_interface_info,
        kompira.core.audit.apply_default_value,
        kompira.core.audit.add_operation_level,
        kompira.core.audit.add_target_level,
        kompira.core.audit.filter_by_level,
        kompira.core.audit.add_finished_time,
        kompira.core.audit.format_datetime,
        kompira.core.audit.drop_debug_info,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
    ],
    context_class=structlog.threadlocal.wrap_dict(dict),
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

#
# 実行コマンドを設定する
#
command_name = len(sys.argv) > 0 and os.path.basename(sys.argv[0])
if command_name:
    multiprocessing.current_process().name = command_name
#
# ログ出力先の振り分け設定
#
command = command_name and os.path.splitext(command_name)[0]
if command == 'manage':
    pass
elif '--debug' in sys.argv:
    LOGGING['loggers']['kompira']['level'] = 'DEBUG'
else:
    log_file = 'kompirad.log' if command == 'kompirad' else \
               'kompira.log'
    LOGGING['handlers']['kompira'] = {
        'level': 'INFO',
        'class': 'logging.handlers.TimedRotatingFileHandler',
        'formatter': 'default',
        'filename': os.path.join(KOMPIRA_LOG_DIR, log_file),
        'when': 'D',
        'backupCount': 7,
    }

#
# 監査ログ設定ファイルのパス
#
KOMPIRA_AUDIT_CONFIG_PATH = os.path.join(KOMPIRA_HOME, 'kompira_audit.yaml')

#
# 監査ログ出力先の設定
# /opt/kompira 環境で動作しているプロセスでは audit-$username.log に出力する
# TODO: 異なるユーザで動作する複数のプロセスからのログ出力を統合できるか（するべきか）検討する
#
if BASE_DIR.startswith(KOMPIRA_HOME):
    LOGGING['handlers']['audit'].update({
        'class': 'kompira.core.audit.WatchedUmaskFileHandler',
        'filename': os.path.join(KOMPIRA_LOG_DIR, f'audit-{Process().username()}.log'),
    })

SELECT2_JS = 'select2-4.0.13/js/select2.min.js'
SELECT2_CSS = 'select2-4.0.13/css/select2.min.css'
SELECT2_I18N_PATH = 'select2-4.0.13/js/i18n'
SELECT2_CACHE_BACKEND = 'select2'

TEMPUS_DOMINUS_LOCALIZE = False
TEMPUS_DOMINUS_INCLUDE_ASSETS = False

AXES_LOCK_OUT_BY_COMBINATION_USER_AND_IP = True # ロックする対象をアカウントとIPの組み合わせにする
AXES_RESET_ON_SUCCESS = True
AXES_FAILURE_LIMIT = 'kompira.core.authentication.get_login_failure_limit'
AXES_COOLOFF_TIME = 'kompira.core.authentication.get_account_lockout_time'
AXES_LOCKOUT_TEMPLATE = 'lockout.html'
AXES_LOCKOUT_CALLABLE = 'kompira.core.authentication.get_lockout_response'
AXES_VERBOSE = False
