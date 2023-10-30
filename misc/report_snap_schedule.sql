-- =====================================================
--  Shows the refresh schedule for RPTP table snapshots
-- =====================================================
SELECT DISTINCT
  a.application application,
  a.table_owner db_schema,
  a.table_name table_name,
  a.pattern refresh_pattern,
  a.frequency frequency,
  to_char(a.last_refresh, 'dd-mon-yyyy') last_refresh,
  to_char(a.next_refresh, 'dd-mon-yyyy') next_refresh
FROM 
  SNAPMASTER.ss_refresh_schedule a
ORDER BY
  a.application,
  a.table_owner,
  a.table_name
;
