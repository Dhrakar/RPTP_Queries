-- search for 'BAD' records in the SSN (#115) keyword table
select 
  kw.keyvaluechar AS "SSN",
  id.itemnum   AS "Document Handle",
  trim(dt.itemtypename) AS "Document Type",
  trim(itemname)        AS "Document Name",
  to_char(id.itemdate, 'MM/DD/YYYY')  AS "Document Date"
from keytable115 kw
left join keyxitem115 kxi on kxi.keywordnum = kw.keywordnum
left join itemdata id on id.itemnum = kxi.itemnum
left join doctype dt on dt.itemtypenum = id.itemtypenum
where kw.keyvaluechar like 'BAD%'
order by kw.keyvaluechar;

select * from keytable116 where upper(keyvaluechar) like '%BAD%';
select * from keytable116;
select * from keyxitem116;

-- search for 'BAD' records in the UAID (#116) keyword table
select 
  kw.keyvaluechar AS "UAID",
  kw.keywordnum   AS "Key #",
  kxi.itemnum     AS "Document Handle",
  kxi.keysetnum   AS "KW set #",
  trim(dt.itemtypename) AS "Document Type",
  trim(itemname)        AS "Document Name",
  to_char(id.itemdate, 'MM/DD/YYYY')  AS "Document Date"
from keytable116 kw
left join keyxitem116 kxi on kxi.keywordnum = kw.keywordnum
left join itemdata id on id.itemnum = kxi.itemnum
left join doctype dt on dt.itemtypenum = id.itemtypenum
where kw.keyvaluechar like '%BAD%'
order by kw.keyvaluechar;

select * from hsi.keytable116 where keyvaluechar  LIKE 'BAD%';
select * from hsi.keyxitem116 where keywordnum = 1675102;
select * from itemdata where itemnum = 1675102;

SELECT keywordnum, keyvaluechar 
FROM hsi.keytable239 
--WHERE keyvaluechar LIKE 'N%'
;

-- 2. Delete strictly the orphaned records matching your criteria
DELETE FROM hsi.keytable116 
WHERE keyvaluechar LIKE '%BAD%'
  AND keywordnum NOT IN (SELECT keywordnum FROM hsi.keyxitem116);
  
SELECT * FROM hsi.keytable116 
WHERE keyvaluechar LIKE '%BAD%'
  AND keywordnum NOT IN (SELECT keywordnum FROM hsi.keyxitem116);
  
-- autofills 
select 
  af.ks115 AS "SSN",
  af.ks116 AS "UAID",
  af.keysetnum AS "Item",
  id.itemnum   AS "Document Handle",
  trim(dt.itemtypename) AS "Document Type",
  trim(itemname)        AS "Document Name",
  to_char(id.itemdate, 'MM/DD/YYYY')  AS "Document Date"
from keysetdata109 af
left join itemdata id on id.itemnum = af.keysetnum
left join doctype dt on dt.itemtypenum = id.itemtypenum
where 
  af.ks116 LIKE '%BAD%'
 -- af.ks115 LIKE '%BAD%'
order by af.ks116;

select * from keysetdata122 where ks116 LIKE '%BAD%';

 select keywordnum
from hsi.keyxitem116
union select keywordnum
from hsi.folderxkey116;

select count(*)
from hsi.keytable116;