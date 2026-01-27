[options]
; Server
proxy_mode = True
xmlrpc_interface = 0.0.0.0
xmlrpc_port = 8069
longpolling_port = 8072

; Paths
data_dir = /var/lib/odoo
addons_path = /opt/odoo/odoo/addons,/mnt/extra-addons,/mnt/custom-addons

; DB
db_host = postgres
db_port = 5432
db_user = odoo
db_password = ${ODOO_DB_PASS}

; Logging
logfile = /var/log/odoo/odoo.log
log_level = info
