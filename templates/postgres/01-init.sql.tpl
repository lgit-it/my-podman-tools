DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'odoo') THEN
      CREATE ROLE odoo LOGIN PASSWORD '${ODOO_DB_PASS}';
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n') THEN
      CREATE ROLE n8n LOGIN PASSWORD '${N8N_DB_PASS}';
   END IF;
END
$do$;

-- Nota: questi CREATE DATABASE vengono eseguiti solo al primo init del volume data.
CREATE DATABASE odoo OWNER odoo;
CREATE DATABASE n8n OWNER n8n;
