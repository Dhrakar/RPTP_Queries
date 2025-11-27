-- ============================================================
--  This script lists out all of the currently defined 
--  OnBase Document Types along with their groups and default
--  Disk Group
-- ============================================================
SELECT
  '[' || lpad(dt.itemtypenum, 3, '0') || '] ' ||
    trim(dt.itemtypename)       AS "[ID#] DocType",
  '[' || lpad(dt.itemtypegroupnum, 3, '0') || '] ' ||
    trim(itg.itemtypegroupname) AS "[ID#] DocType Group",
  '[' || dt.diskgroupnum || '] ' ||
    trim(dg.diskgroupname)      AS "[ID#] DocType Default Disk Group",
  -- comment out if not doing totals
--  count(distinct itd.itemnum)   AS "Total Documents"
  -- --------------------------------
  -- comment out if doing totals
  LISTAGG (
    substr(trim(ug.usergroupname),11), 
    ', '
  ) WITHIN GROUP (
    order by ug.usergroupnum
  )                           AS "(ua_onbase.) Access Groups"
  -- ---------------------------------
FROM
  HSI.DOCTYPE dt
  -- comment out if not getting doc totals
--  INNER JOIN HSI.ITEMDATA itd ON (
--    dt.itemtypenum = itd.itemtypenum
--  )
  -- -------------------------------------
  INNER JOIN HSI.ITEMTYPEGROUP itg ON
    itg.itemtypegroupnum = dt.itemtypegroupnum
  INNER JOIN HSI.DISKGROUP dg ON
    dg.diskgroupnum = dt.diskgroupnum
  INNER JOIN HSI.USERGROUPCONFIG ugc ON 
    ugc.itemtypenum = dt.itemtypenum
  INNER JOIN HSI.USERGROUP ug ON
    ug.usergroupnum = ugc.usergroupnum
WHERE
  -- don't report the sys default type
  dt.itemtypenum > 0
  AND dt.itemtypename LIKE 'FIN%'
  --AND ( dt.itemtypename LIKE 'HR%' OR dt.itemtypename LIKE 'INTL%' )
GROUP BY
  '[' || lpad(dt.itemtypenum, 3, '0') || '] ' ||      trim(dt.itemtypename),
  '[' || lpad(dt.itemtypegroupnum, 3, '0') || '] ' || trim(itg.itemtypegroupname),
  '[' || dt.diskgroupnum || '] ' ||     trim(dg.diskgroupname)
ORDER BY
  2,1
;