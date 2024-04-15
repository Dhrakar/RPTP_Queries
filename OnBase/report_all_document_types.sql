-- ============================================================
--  This script lists out all of the currently defined 
--  OnBase Document Types along with their groups and default
--  Disk Group
-- ============================================================
SELECT
  '[' || lpad(dt.itemtypenum, 3, '0') || '] ' ||
    trim(dt.itemtypename)       AS "DocType",
  '[' || lpad(dt.itemtypegroupnum, 3, '0') || '] ' ||
    trim(itg.itemtypegroupname) AS "DocType Group",
  '[' || dt.diskgroupnum || '] ' ||
    trim(dg.diskgroupname)      AS "DocType Default Disk Group",
  LISTAGG (
    substr(trim(ug.usergroupname),11), 
    ', '
  ) WITHIN GROUP (
    order by ug.usergroupnum
  )                           AS "(ua_onbase.) Access Group"
FROM
  HSI.DOCTYPE dt
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
GROUP BY
  '[' || lpad(dt.itemtypenum, 3, '0') || '] ' ||      trim(dt.itemtypename),
  '[' || lpad(dt.itemtypegroupnum, 3, '0') || '] ' || trim(itg.itemtypegroupname),
  '[' || dt.diskgroupnum || '] ' ||     trim(dg.diskgroupname)
ORDER BY
  -- '[' || lpad(dt.itemtypegroupnum, 3, '0') || '] ' || trim(itg.itemtypegroupname),
  '[' || lpad(dt.itemtypenum, 3, '0') || '] ' || trim(dt.itemtypename)
;