-- builds list of the doctypes associated with a specific user group
SELECT
  dpg.usergroupnum AS "Grp ID",
  trim(ug.usergroupname) AS "User Group",
  dpg.itemtypenum AS "Doc ID",
  trim(dt.itemtypename) AS "Document Type",
  count(distinct docs.itemnum) AS "Doc Count"
FROM
  HSI.USERGROUPCONFIG dpg 
  INNER JOIN HSI.USERGROUP ug ON (
    ug.usergroupnum = dpg.usergroupnum
  )
  INNER JOIN HSI.DOCTYPE dt ON (
    dt.itemtypenum = dpg.itemtypenum
  )
  INNER JOIN HSI.ITEMDATA docs ON (
    docs.itemtypenum = dpg.itemtypenum
  )
WHERE
  ug.usergroupname LIKE '%dept%'
GROUP BY
  dpg.usergroupnum,
  trim(ug.usergroupname),
  dpg.itemtypenum,
  trim(dt.itemtypename)
ORDER BY
  dpg.usergroupnum,
  dpg.itemtypenum
;

select * from itemdata;