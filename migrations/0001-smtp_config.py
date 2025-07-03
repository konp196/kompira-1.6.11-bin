from kompira.models.extends import get_object
import json

conf = get_object('/system/config')
data = {
    "objpath": "/system/smtp_servers/Default",
    "typepath": "/system/types/SmtpServer",
    "fields": {
        'hostname': conf.data['SMTPServer'],
        'port': conf.data['SMTPPort'],
        'username': conf.data['SMTPUser'],
        'password': conf.data['SMTPPassword'],
        'use_tls': conf.data['SMTPUseTLS'],
        'use_ssl': conf.data['SMTPUseSSL']
    }
}
print(json.dumps([data]))
