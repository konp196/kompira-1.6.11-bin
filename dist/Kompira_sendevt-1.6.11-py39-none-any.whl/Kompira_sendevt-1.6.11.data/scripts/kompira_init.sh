#! /bin/bash
#
# kompira_init.sh: Processing before starting each kompira service
#

if [ -f /opt/kompira/bin/ssl_utils.sh ] && [ ! -d /opt/kompira/ssl ]; then
    /opt/kompira/bin/ssl_utils.sh server-setup
fi
