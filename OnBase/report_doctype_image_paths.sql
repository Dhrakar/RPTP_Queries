-- Find all Contract letters for a list of UAIDs
-- 
-- doctype 'HR Contract/Appointment Letter' => 607
SELECT DISTINCT
  -- trim(emp.keyvaluechar)                  AS "Employee ID",
  -- PowerShell copy command for this document page
  'Copy-Item ' || 
    -- 'From' location in OnBase server
    '"F:\DDIProd\' || UPPER(trim(dg.diskgroupname)) || trim(idp.filepath) ||
    -- 'to' location in temporary drive
    '" -Destination "D:\extract\' ||  
  --  UAID number                           File Name  
      trim(emp.keyvaluechar) ||  '_' || trim(substr(idp.filepath,1+instr(idp.filepath, '\',  -1))) ||                           
    '"'                          AS "Copy Command"
FROM
  HSI.DOCTYPE doc
  -- get the basic item data and identifiers
  JOIN HSI.ITEMDATA id       ON doc.itemtypenum = id.itemtypenum
  -- get the storage location path
  JOIN HSI.ITEMDATAPAGE idp  ON id.itemnum = idp.itemnum
  -- get the associated disk group
  JOIN HSI.DISKGROUP dg      ON idp.diskgroupnum = dg.diskgroupnum
  JOIN HSI.KEYXITEM116 uaid  ON id.itemnum = uaid.itemnum
  JOIN HSI.KEYTABLE116 emp   ON uaid.keywordnum = emp.keywordnum
WHERE
  -- contract doc type
  doc.itemtypenum = 607
  -- limit to things uploaded this FY
  AND id.datestored > to_date('01/07/2023', 'dd/mm/yyyy')
  -- limit to jsut the list of UAIDs from HR
  AND emp.keyvaluechar IN (
    SELECT uaid
    FROM HSI.ZZ_TMP
  )
ORDER BY 
 1
;

