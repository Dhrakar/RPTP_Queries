SELECT
  trim(b.parsefilename) AS "Process Name",
  (
    SELECT
      itemtypename
    FROM
      HSI.DOCTYPE
    WHERE
      itemtypenum = proc.itemtypenum
  )  AS "Doc Type"
FROM 
  HSI.PARSEFILEXITMTYP proc
  INNER JOIN HSI.PARSEFILEDESC b ON (
    b.parsefilenum = proc.parsefilenum
  )
WHERE
  proc.parsefilenum IN (
    136,-- NextGen
    137,-- SalesForce
    138,-- Tax 
    148 -- RO FERPA
  )
ORDER BY
  1,2
;

select * from parsefiledesc;