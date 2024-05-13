-- ==================================================
-- Various queries provided by Hyland during our 
-- recent upgrade to EP3.  They are intended to show
-- the state of things that may cause issues when 
-- prepping for the upgrade
-- ==================================================

-- get the version of the overall Oracle database
SELECT * FROM V$VERSION;

/*-----------------------------------------------
	Average Doc Size by Doc Type
*/-----------------------------------------------

-- set transaction isolation level read uncommitted

select dt.itemtypename, avg(cast(docsize as number))/1024 as avgsizekb 
from hsi.itemdata i join
(select itemnum, SUM(cast(filesize as number)) as docsize, COUNT(*) as pagecnt
	from hsi.itemdatapage
	group by itemnum) f on f.itemnum = i.itemnum
join hsi.doctype dt on dt.itemtypenum = i.itemtypenum
group by dt.itemtypename
;

/*-----------------------------------------------
	Scan Queue VB Script Hooks
*/-----------------------------------------------
-- set transaction isolation level read uncommitted

SELECT st.vbscriptnum As "VB Script Num", st.vbscriptname As "Script Name", sq.queuename As "Scan Queue",
CASE 
when sh.keykeytype = 1001 then 'Post-Index'
when sh.keykeytype = 1002 then 'Pre-Commit (Scan)'
when sh.keykeytype = 1003 then 'Post-Commit (Scan)'
when sh.keykeytype = 1004 then 'Pre-Commit (Parsed)'
when sh.keykeytype = 1005 then 'Post-Commit (Parsed)'
when sh.keykeytype = 1006 then 'Document Cross Reference'
when sh.keykeytype = 1007 then 'Post Secondary Index'
when sh.keykeytype = 1008 then 'Post Batch Re-Index'
when sh.keykeytype = 1009 then 'Document Re-Index'
when sh.keykeytype = 1010 then 'Index Document Into Existing'
when sh.keykeytype = 1011 then 'File Import'
when sh.keykeytype = 1012 then 'Add/Modify Keywords'
when sh.keykeytype = 1013 then 'Pre-Scan'
when sh.keykeytype = 1014 then 'Post-Scan'
when sh.keykeytype = 1015 then 'Post-Scan More'
when sh.keykeytype = 1016 then 'Add Document to DKT Reading Group'
when sh.keykeytype = 1017 then 'Archive Doc Into MR Chart'
when sh.keykeytype = 1018 then 'Before Save Office Document'
when sh.keykeytype = 1019 then 'After Save Office Document'
when sh.keykeytype = 1020 then 'Post-Index Office Document'
when sh.keykeytype = 1021 then 'Scan Queue Pre-Index Document'
when sh.keykeytype = 1022 then 'Post-Index file Import Dialog'
when sh.keykeytype = 1023 then 'Scan Queue Document Type Change In Indexing Panel'
when sh.keykeytype = 1024 then 'Scan Queue Ad-hoc Indexing Panel Script'
when sh.keykeytype = 1025 then 'Post-Generate Import File List For Sweep and Scan From Disk'
when sh.keykeytype = 1026 then 'Post Archive Re-Index Document Dialog'
when sh.keykeytype = 1027 then 'Post-Archive Document As Revision of Existing'
when sh.keykeytype = 1028 then 'Scan Queue Imprinter/Endorser Hook'
when sh.keykeytype = 1029 then 'Automated Index Point and Shoot OCR'
when sh.keykeytype = 1030 then 'Scan Queue Sweeep Document'
when sh.keykeytype = 1031 then 'Post Archive Send-To Create New Document'
when sh.keykeytype = 1032 then 'Scan Queue Focus'
when sh.keykeytype = 1033 then 'Scan Queue Blur'
when sh.keykeytype = 1034 then 'Automated Redaction Hit Detected'
END AS "Script Hook"
FROM hsi.vbscripttable st
JOIN hsi.vbscripthooks sh ON st.vbscriptnum = sh.vbscriptnum
join hsi.scanqueue sq on sq.queuenum = sh.keyvalue
AND sh.keykeytype != 0
;
/*-----------------------------------------------
WF Actions
-- (PAV3 4/13/2020)
--Work in Progress, does not include Call WCF Service, Export to Network Location, or Send Workview Notification.  
--All three should be checked in additon to the script results
*/-----------------------------------------------

-- set transaction isolation level read uncommitted

select DISTINCT(act.actionnum),act.actionname, lc.lifecyclename,
CASE 
when act.actiontype = 82 then 'Run Script'
when act.actiontype = 167 then 'Call Web Service'
when act.actiontype = 155 then 'Display URL'
when act.actiontype = 169 then 'Run Unity Script'
when act.actiontype = 162 then 'Send Web Request'
END
from hsi.action act
join hsi.tasklistxtask tlxt on tlxt.tasknum = act.actionnum
join hsi.tasklist tl on tl.tasklistnum = tlxt.tasklistnum
join hsi.lifecycle lc on lc.lcnum = tl.scope
where act.actiontype in (82,167,155,169,162)
order by act.actionname
;

/*-----------------------------------------------
	logins for Core by month and registernum
	always try to run, but off hours 
	this just gives an idea of from where most users connect - don't necessarily report or graph this info	
*/-----------------------------------------------

-- set transaction isolation level read uncommitted

--Original query:
--SELECT extract( year from sl.logdate) as "Year", extract(month from sl.logdate) as "Month",sl.registernum, ru.registername
--	-- substring(sl.messagetext,instr('Services',sl.messagetext,0)+9, instr('on', sl.messagetext,instr('Services',sl.messagetext,0)+9 )-(instr('Services',sl.messagetext,0)+9) ) as "version", COUNT(*) as LoginCount
--FROM hsi.securitylog sl
--JOIN hsi.registeredusers ru ON sl.registernum=ru.registernum
--WHERE ((sl.actionnum = 1 and sl.subactionnum = 9) /*OR (sl.actionnum = 3 and sl.subactionnum = 7)*/)
--AND sl.logdate > '2012-01-01 00:00:00.000'
--GROUP BY datepart(yyyy,sl.logdate), datepart(mm,sl.logdate), sl.registernum, ru.registername --, substring(sl.messagetext,instr('Services',sl.messagetext,0)+9,instr('on', sl.messagetext,instr('Services',sl.messagetext,0)+9 )-(instr('Services',sl.messagetext,0)+9) )--,charindex('on', sl.messagetext,charindex('Services',sl.messagetext,0)+9 )-(charindex('Services',sl.messagetext,0)+9)
--ORDER BY datepart(yyyy,sl.logdate), datepart(mm,sl.logdate), COUNT(*) DESC
--;

SELECT
  extract( year from sl.logdate) as "Year", 
  extract(month from sl.logdate) as "Month",
  sl.registernum "System ID", 
  trim(ru.registername) AS "System Name",
  substr(
    sl.messagetext,
    instr(sl.messagetext, 'Services') + 9,
    instr(sl.messagetext, 'on', instr(sl.messagetext, 'Services') + 9) 
    - (instr(sl.messagetext, 'Services') + 9)
  ) AS "Version",
  count(sl.securitylognum) AS "Log Count"
FROM 
  hsi.securitylog sl
  JOIN hsi.registeredusers ru ON sl.registernum=ru.registernum
WHERE 
  (sl.actionnum = 1 and sl.subactionnum = 9)
  AND sl.logdate > to_date('01-JAN-2015', 'DD-MON-YYYY')
GROUP BY
  extract(year from sl.logdate), 
  extract(month from sl.logdate),
  sl.registernum, 
  trim(ru.registername),
  substr(
    sl.messagetext,
    instr(sl.messagetext, 'Services') + 9,
    instr(sl.messagetext, 'on', instr(sl.messagetext, 'Services') + 9) 
    - (instr(sl.messagetext, 'Services') + 9)
  )
ORDER BY
  extract(year from sl.logdate), 
  extract(month from sl.logdate),
  count(sl.securitylognum) DESC
;


/*
	Docs stored by doc type 
	always run; can run during the day, should use itemdata10
	more informational, not necessarily important to perf
*/

-- set transaction isolation level read uncommitted

SELECT 
	i.itemtypenum, 
	dt.itemtypename, 
	COUNT(*) AS "Count" 
FROM hsi.itemdata i
JOIN hsi.doctype dt ON i.itemtypenum=dt.itemtypenum
GROUP BY i.itemtypenum, dt.itemtypename
ORDER BY i.itemtypenum
;

/*
	docs stored by month 
	always try to run, but off hours since it aggregates on datestored
	use this output to then get docs/year (or, write another query that aggregates only by year...)
	combined with avg doc size, for growth trending/projection
*/

-- set transaction isolation level read uncommitted

SELECT 
	extract( year from datestored) as "Year", 
	extract( month from datestored) as "Month",
	COUNT(*) as "Count"
FROM hsi.itemdata 
GROUP BY extract( year from datestored), extract( month from datestored)
ORDER BY extract( year from datestored), extract( month from datestored)
;
--External Keyword Sets:
select ktt.keytypenum, ktt.keytype, kwds.selectstring, kwds.connectstring
from hsi.keytypetable ktt
join hsi.keyworddataset kwds on ktt.keytypenum = kwds.keytypenum
order by ktt.keytype
; 
--External Autofills:
Select keysetname, selectstring, connectstring
From hsi.keywordset
;
--Parsing Path information (COLD, DIP, etc)
SELECT  parsefilenum AS "Process Number", 
CASE 
when bitand(parsingmethod,  104) = 104 then 'Branch Capture Check Processor'
when bitand(parsingmethod,  89) = 89 then 'XML Document Import Processor'
when bitand(parsingmethod,  87) = 87 then 'Physical Recordd Import Processor'
when bitand(parsingmethod,  77) = 77 then 'AFP Tagged Parser'
when bitand(parsingmethod,  76) = 76 then 'HL7 Batch File Parser'
when bitand(parsingmethod,  75) = 75 then '837 Dental Parser'
when bitand(parsingmethod,  74) = 74 then '837 Institutional Parser'
when bitand(parsingmethod,  73) = 73 then '937 Professional Parser'
when bitand(parsingmethod,  72) = 72 then '835 Parser'
when bitand(parsingmethod,  71) = 71 then 'Tagged Import Processor'
when bitand(parsingmethod,  70) = 70 then 'Document Retention Update Processor'
when bitand(parsingmethod,  69) = 69 then 'DJDE'
when bitand(parsingmethod,  67) = 67 then 'AFP Parser'
when bitand(parsingmethod,  64) = 64 then 'Keyword Update'
when bitand(parsingmethod,  47) = 47 then 'Document Retention Delete Processor'
when bitand(parsingmethod,  41) = 41 then 'PDF'
when bitand(parsingmethod,  40) = 40 then 'Autofill Importer'
when bitand(parsingmethod,  37) = 37 then 'PCL'
when bitand(parsingmethod,  4) = 4 then 'DIP' 
when bitand(parsingmethod,  3) = 3 then 'Dictionary Import Parser'
when bitand(parsingmethod,  2) = 2 then 'COLD'
when bitand(parsingmethod,  1) = 1 then 'COLD'
ELSE 'other'
END AS "Prcoess Type",
parsefilename AS "Process Name", 
defdirname AS "Default Directory",
deffilename AS "Deafult File Name", 
preprocesspath AS "Preprocessor Path", 
preprocparams AS "Preprocessor Parameters", 
backupdirname AS "Backup Directory",
ftpfilepath AS "FTP Path",
ftpusername AS"FTP User Name",
ftppassword AS "FTP Password" 
FROM        hsi.parsefiledesc
;

--Sweep processes: Path information
SELECT queuenum "Scan Queue Number", 
queuename "Scan Queue Name", 
sweepdir "Sweep Directory" 
FROM hsi.scanqueue 
WHERE sweepdir <> ''
;

--HL7 Dump to File Path References
select hl7messagenum, hl7processname, dumppath
from hsi.hl7inputprocess
where processtype = 1
;

--HL7 Advanced Document Import Processes (Check these to verify if Path Reference is set as the Data Format)
select hl7processnum, hl7processname
from hsi.hl7inputprocess
where processtype = 13
;

-- gets a list of all the WF user forms used and their paths
SELECT
  uf.formnum             AS "Form ID",
  trim(uf.formname)      AS "Form Name",
  trim(uf.pathtofile)    AS "Form UNC Path",
  trim(lc.lifecyclename) AS "WF Lifecycle",
  trim(act.actionname)   AS "WF Action Name"
FROM
  hsi.wfform uf
  JOIN hsi.action act on uf.formnum = act.formnum
  JOIN hsi.lifecycle lc on uf.scope = lc.lcnum
ORDER BY
  trim(lc.lifecyclename),
  trim(act.actionname)
;

-- get a list of the custom queries that use HTML forms
SELECT 
  cq.cqnum            AS "Custom Query ID",
  trim(cq.cqname)     AS "Custom Query",
  trim(cq.fromclause) AS "HTML Form UNC"
FROM
  hsi.customquery cq 
WHERE
  cq.fromclause IS NOT NULL
  AND cq.whereclause IS NULL
;

-- get a list of all of the UNCs used for the disk paths
SELECT
  pl.physicalplatternum   AS "Platter ID",
  trim(dg.diskgroupname)  AS "Disk Group",
  trim(pl.lastuseddrive)  AS "Path"
FROM
  hsi.physicalplatter pl
  JOIN hsi.diskgroup dg ON pl.diskgroupnum = dg.diskgroupnum
ORDER BY 
  pl.physicalplatternum, trim(dg.diskgroupname)
;

-- list the disk groups
SELECT
  trim(dg.diskgroupname) AS "Disk Group",
  DECODE ( dg.ucautopromotespace,
     500000, 'CD',
    3800000, 'DVD Small File',
    4000000, 'DVD Large FIle',
   22600000, 'BD Small File',
   24000000, 'BD Large File',
   'Custom'
  )  AS "DG Type",
  lp.logicalplatternum AS "Platter #",
  lp.createtime AS "Platter Created Date"
FROM
  HSI.DISKGROUP dg
  JOIN HSI.PHYSICALPLATTER pp ON dg.diskgroupnum = pp.diskgroupnum
  JOIN HSI.LOGICALPLATTER lp ON (
    dg.diskgroupnum = lp.diskgroupnum
    AND pp.logicalplatternum = lp.logicalplatternum
  )
ORDER BY
  dg.diskgroupname,
  lp.logicalplatternum,
  pp.physicalplatternum
;

describe DISKGROUP;
describe logicalplatter;

SELECT DISTINCT 
  dg.diskgroupnum         AS "ID",
  trim(dg.diskgroupname)  AS "Name",
  decode (
    flags,
    '2', 'Encrypted',
    ' '
  )                       AS "Flags"
FROM
  HSI.DISKGROUP dg
WHERE
  lower(dg.diskgroupname) NOT LIKE '%(rem%'
ORDER BY
  3 DESC,1
;
