-- owners.sql

-- Object ownership

-- r = ordinary table, i = index, S = sequence, 
-- v = view, m = materialized view, c = composite type, 
-- t = TOAST table, f = foreign table, p = function/procedure

SELECT owner_id, owner_name, schema_name, rel_kind
	, count(*)
from (
	SELECT n.nspname as schema_name
	 , c.relname as rel_name
	 , c.relkind as rel_kind
	 , c.relowner as owner_id
	 , pg_get_userbyid(c.relowner) as owner_name
	FROM pg_class c
	JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN (
	'pg_toast'
, 'pg_catalog'
, 'information_schema'
)
  and n.nspname NOT LIKE 'pg_temp_%'
  and n.nspname NOT LIKE 'pg_toast_temp_%'

	UNION ALL

	SELECT n.nspname as schema_name
	 , p.proname
	 , 'p'
	 , p.proowner
	 , pg_get_userbyid(p.proowner)
	FROM pg_proc p
	JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN (
	'pg_toast'
, 'pg_catalog'
, 'information_schema'
)
  and n.nspname NOT LIKE 'pg_temp_%'
  and n.nspname NOT LIKE 'pg_toast_temp_%'

) as dbobjects
GROUP BY owner_id, owner_name, schema_name, rel_kind
ORDER BY 2, 3, 4
;
