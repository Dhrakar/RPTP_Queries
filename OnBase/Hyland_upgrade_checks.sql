-- ==================================================
-- Various queries provided by Hyland during our 
-- recent upgrade to EP3.  They are intended to show
-- the state of things that may cause issues when 
-- prepping for the upgrade
-- ==================================================

-- get the version of the overall Oracle database
SELECT * FROM V$VERSION;

-- get the version of the onbase schema
SELECT trim(dbversion) FROM hsi.licensetable;

-- temp cache
Select trim(cachename) as "Cache Name", trim(cachedir) as "Cache Location" From hsi.tempcache;

-- Server names
select trim(prettyservername) as "Server Name", trim(serveraddress) as "Server Address", serverport as "Port" from hsi.fileserviceserver;


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

-- list of eforms
select trim(dt.itemtypename) as DocType, dte.itrevnum as "Revision #", trim(kt1.keyvaluechar) as Description,
id.datestored as DateStored, id.itemnum as "Doc Handle"
from hsi.dtelectronicform dte
join hsi.doctype dt on dt.itemtypenum = dte.itemtypenum
join hsi.keyxitem1 kxi on kxi.itemnum = dte.formitemnum
join hsi.keytable1 kt1 on kt1.keywordnum = kxi.keywordnum
join hsi.itemdata id on id.itemnum = dte.formitemnum
order by dt.itemtypename, dte.itrevnum;

-- style sheets
select dts.stylename as "StyleSheet", dt.itemtypename as "Doc Type", dts.stylepath as "View Style Sheet", 
dts.printstylepath as "Print Style Sheet"
from hsi.doctypexmlstyle dts
join hsi.doctype dt on dts.itemtypenum = dt.itemtypenum
order by dt.itemtypename;

-- gets a list of all the WF user forms used and their paths
SELECT
  uf.formnum             AS "Form ID",
  trim(uf.formname)      AS "Form Name",
  trim(uf.pathtofile)    AS "Form UNC Path",
  trim(lc.lifecyclename) AS "WF Lifecycle",
  trim(ls.statename)     AS "WF Queue",
  trim(act.actionname)   AS "WF Action Name"
FROM
  hsi.wfform uf
  JOIN hsi.action act on uf.formnum = act.formnum
  JOIN hsi.lifecycle lc on uf.scope = lc.lcnum
  JOIN hsi.lcstate ls on ls.scope = uf.scope
ORDER BY
  trim(lc.lifecyclename),
  trim(act.actionname)
;

-- get a list of the custom queries that use HTML forms
SELECT 
  cq.cqnum            AS "Custom Query ID",
  trim(cq.cqname)     AS "Custom Query",
  trim(cq.fromclause) AS "FROM / HTML Form UNC",
  trim(cq.whereclause) AS "WHERE clause",
  trim(cq.sortclause) AS "Sort clause"
FROM
  hsi.customquery cq 
WHERE
  cq.fromclause IS NOT NULL
  -- AND cq.whereclause IS NULL
;

-- VB Scripts
SELECT vbscriptnum || ': ' || vbscriptname as "Script Name", vbscript as "Script Details"
FROM hsi.vbscripttable;

-- VB Script hooks
SELECT st.vbscriptname As "Script Name", sq.queuename As "Scan Queue",
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

-- get a list of all of the UNCs used for the disk paths
SELECT
  pl.physicalplatternum   AS "Platter ID",
  trim(dg.diskgroupname)  AS "Disk Group",
  trim(pl.lastuseddrive)  AS "Path"
FROM
  hsi.physicalplatter pl
  JOIN hsi.diskgroup dg ON pl.diskgroupnum = dg.diskgroupnum
ORDER BY 
  pl.physicalplatternum
;

-- list the disk groups
select rtrim(dg.diskgroupname) as DiskGroupName, pp.physicalplatternum as Copy, pp.logicalplatternum as Volume, rtrim(pp.lastuseddrive) as Location
from hsi.physicalplatter pp 
join hsi.diskgroup dg on dg.diskgroupnum = pp.diskgroupnum
order by dg.diskgroupname, pp.physicalplatternum, pp.logicalplatternum;

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
  1
;

-- Import processes
SELECT parsefilename as ProcessName,
case when parsingmethod in (1,2) then 'COLD'
	 when parsingmethod = 3 then 'Dictionary Import Processor'
	 when parsingmethod = 4 then 'Document Import Processor (DIP)'
	 when parsingmethod = 65540 then 'Tagged DIP' --4 + 65536 = 65540 = Tagged DIP
	 when parsingmethod = 131076 then 'Ordered DIP' --4 + 131072 = 131076 = Ordered DIP
	 when parsingmethod = 262148 then 'Self Configured DIP' --4 + 262144 = 262148 = Self Configured DIP
	 when parsingmethod = 5 then 'Wausau Check Images'
	 when parsingmethod = 6 then 'Federal Reserve (Lakewood) Check Images'
	 when parsingmethod = 7 then 'Unysis Check Images (Data File)'
	 when parsingmethod = 8 then 'Federal Reserve (Kevin Freed)'
	 when parsingmethod = 9 then 'Federal Reserve ( West )'
	 when parsingmethod = 10 then 'Unisys Native'
	 when parsingmethod = 11 then 'Unisys DP35'
	 when parsingmethod = 12 then 'Generic Flat'
	 when parsingmethod = 13 then 'DSI Check Processing Format'
	 when parsingmethod = 14 then '7780 Check Processing Format'
	 when parsingmethod = 15 then 'Motorola Check Processing Format'
	 when parsingmethod = 16 then 'CAPI Check Processing Format'
	 when parsingmethod = 17 then 'IBM'
	 when parsingmethod = 18 then 'NCR Signature Card Processing'
	 when parsingmethod = 19 then 'Eastern Fed 16 Byte'
	 when parsingmethod = 20 then 'COF Format'
	 when parsingmethod = 21 then 'ITI Capi Match format'
	 when parsingmethod = 22 then 'ITI Motorola Match format'
	 when parsingmethod = 23 then 'COF Repass'
	 when parsingmethod = 24 then 'Eastern Fed Repass'
	 when parsingmethod = 25 then 'Eastern Fed 16 Repass'
	 when parsingmethod = 26 then 'ITI Director Image Import'
	 when parsingmethod = 27 then 'Wausau Check Reprocessor'
	 when parsingmethod = 28 then 'Kirchman Check Processor'
	 when parsingmethod = 29 then 'OPPD Check Processor'
	 when parsingmethod = 30 then 'ImageSoft Fed JPG Processor'
	 when parsingmethod = 31 then 'Fed Lin Processor (Philly)'
	 when parsingmethod = 32 then 'Monarch Indexer Process'
	 when parsingmethod = 33 then 'Comingle Process'
	 when parsingmethod = 34 then 'VPTA Check Process'
	 when parsingmethod = 35 then 'DSI Repass Process'
	 when parsingmethod = 36 then 'Recall Items Process'
	 when parsingmethod = 37 then 'PCL COLD Process'
	 when parsingmethod = 38 then 'PRINTSET Parser'
	 when parsingmethod = 39 then 'NCR Processor'
	 when parsingmethod = 40 then 'Keyset Import Processor'
	 when parsingmethod = 41 then 'PDF COLD Parsing'
	 when parsingmethod = 42 then 'Kirchman Statement Format'
	 when parsingmethod = 43 then 'HTML'
	 when parsingmethod = 44 then 'ITI''s Correction Notice Processor'
	 when parsingmethod = 45 then 'ITI''s IPS Check Processor'
	 when parsingmethod = 46 then 'Document Retention Update Processor'
	 when parsingmethod = 47 then 'Document Retention Delete Processor'
	 when parsingmethod = 48 then 'Customer Info Importor Processor'
	 when parsingmethod = 49 then 'Generic Titan Check Processor'
	 when parsingmethod = 50 then 'POD CAPI processor'
	 when parsingmethod = 51 then 'Lock box parser'
	 when parsingmethod = 52 then 'IPS Repass'
	 when parsingmethod = 53 then 'Check Vision'
	 when parsingmethod = 54 then 'G.G. Pulley'
	 when parsingmethod = 55 then 'Wausau''s RPS Remit Parser'
	 when parsingmethod = 56 then 'BancTec Praser'
	 when parsingmethod = 57 then 'NCRColombia Parser'
	 when parsingmethod = 58 then 'Wausau JPG Process'
	 when parsingmethod = 59 then 'Mitek Process'
	 when parsingmethod = 60 then 'ABIC Process'
	 when parsingmethod = 61 then 'CSC Process'
	 when parsingmethod = 62 then 'ADF Decisioning Parser'
	 when parsingmethod = 63 then 'ADF Decisioning MSG Parser'
	 when parsingmethod = 64 then 'Keyword Update'
	 when parsingmethod = 65 then 'KWADMIN'
	 when parsingmethod = 66 then 'Imagesoft''s Check-Pay Processor'
	 when parsingmethod = 67 then 'AFP Parser'
	 when parsingmethod = 68 then 'Statement Parser'
	 when parsingmethod = 69 then 'DJDE Parser'
	 when parsingmethod = 70 then 'Metavante Printset Processor'
	 when parsingmethod = 71 then 'TIP Processor'
	 when parsingmethod = 72 then '835 Parser'
	 when parsingmethod = 73 then '837 Professional Parser'
	 when parsingmethod = 74 then '837 Institutional Parser'
	 when parsingmethod = 75 then '837 Dental Parser'
	 when parsingmethod = 76 then '810 Parser'
	 when parsingmethod = 77 then 'HL7 Batch File Parser'
	 when parsingmethod = 78 then 'Syntel integration processor'
	 when parsingmethod = 80 then 'GG Pulley Custom Check Processor'
	 when parsingmethod = 81 then 'Checkfree Positive Pay Processor'
	 when parsingmethod = 82 then 'ADF Notification Parser'
	 when parsingmethod = 83 then '937 Parser'
	 when parsingmethod = 84 then 'IST Quick Capture'
	 when parsingmethod = 85 then 'MVS Retrieval Process'
	 when parsingmethod = 86 then 'AFP Tagged Parser'
	 when parsingmethod = 87 then 'Physical Record Import Processor'
	 when parsingmethod = 88 then 'Wausau Repass Parser'
	 when parsingmethod = 89 then 'Branch Capture'
	 when parsingmethod = 90 then 'Sparak NSF Return Processor'
	 when parsingmethod = 91 then 'Wausau Financial Lockbox Parser'
	 when parsingmethod = 92 then 'Wachovia Check Image Parser'
	 when parsingmethod = 93 then 'Wausau Financial Lockbox Report Importer'
	 when parsingmethod = 94 then 'NonPostRepost Original'
	 when parsingmethod = 95 then 'NonPostRepost CBS 2.1'
	 when parsingmethod = 96 then 'NonPostRepost Version CBS 6.1'
	 when parsingmethod = 97 then 'Incoming return 9.37'
	 when parsingmethod = 98 then 'GoldLeaf Modified 937 for Merchant Capture'
	 when parsingmethod = 99 then 'Snagglepuss Package Receiver'
	 when parsingmethod = 100 then 'Wausau Merchant Capture Integration'
	 when parsingmethod = 101 then 'COF with Orientation'
	 when parsingmethod = 102 then 'XML Document Import Processor'
	 when parsingmethod = 103 then 'Intelligent OCR (College Transcripts - Store XML as revision on image)'
	 when parsingmethod = 104 then 'Branch Capture Check Processor - XML Format'
	 when parsingmethod = 105 then 'Lockbox for ADF version > 7.1.0'
	 when parsingmethod = 112 then 'Imagesoft Vision NSF return Processor'
	 when parsingmethod = 113 then 'Imagesoft Vision NSF return Processor'
	 when parsingmethod = 114 then 'Volume Tracking Pull Slips'
	 when parsingmethod = 115 then 'Imagestar XML File Check Processor'
	 when parsingmethod = 116 then 'Synchronization Services'
	 when parsingmethod = 117 then 'Miser Third Federal NSF return Processor'
	 when parsingmethod = 118 then 'Physician import processor'
else trim(parsingmethod)
end as ProcessType, defdirname as DefaultDirectory, deffilename as DefaultFileName, backupdirname as BackupLocation,
preprocesspath as PreprocessorPath, preprocparams as PreProcessorParameters, ftpfilepath as FTPLocation
FROM hsi.parsefiledesc
order by parsingmethod
;

-- scan queues
SELECT queuename "Scan Queue Name", sweepdir "Sweep Directory" 
FROM hsi.scanqueue 
WHERE sweepdir <> ''
;

-- process jobs
SELECT bf.batchfilename "Process Job", pfd.parsefilename "Process Name", pc.alternatepath "Alternate Path", pc.alternatefilename "Alternate File Name"
FROM hsi.parsecontrol pc
JOIN hsi.parsefiledesc pfd ON pc.parsefilenum = pfd.parsefilenum
JOIN hsi.batchfile bf on pc.controlnum = bf.batchfilenum
;

-- Schedule Processes
SELECT rtrim(sp.schedprocname) as ProcessName, 
rtrim(r.registername) as Workstation,
case
  when sp.lastprocdate = 0 then 'Not Processed'
  else to_char(to_date(sp.lastprocdate, 'yyyymmdd'), 'dd-mon-yyyy') 
end as LastProcessDate,
case
  when sp.lastprocdate = 0 then 'Not Processed'
  when (sp.lastproctime/60) >= 12 then 
    case 
      when length(to_char(mod(sp.lastproctime,12))) = 1 then to_char(floor(sp.lastproctime/60 - 12)) || ':0' || to_char(mod(sp.lastproctime,12)) || ' PM'
      else to_char(sp.lastproctime/60 - 12) || ':' || to_char(mod(sp.lastproctime,12)) || ' PM'
    end
  when (sp.lastproctime/60) < 12 then 
    case 
      when length(to_char(mod(sp.lastproctime,12))) = 1 then to_char(floor(sp.lastproctime/60)) || ':0' || to_char(mod(sp.lastproctime,12)) || ' AM'
      else to_char(sp.lastproctime/60) || ':' || to_char(mod(sp.lastproctime,12)) || ' AM'
    end
  else to_char(sp.lastproctime)
end as LastProcessTime,
rtrim(sp.localinstanceid) as LocalInstanceID
from hsi.scheduledprocess sp
JOIN hsi.registeredusers r on sp.registernum = r.registernum
order by sp.schedprocname;

select * from hsi.scheduledprocess;
-- core/classic timers
select
rtrim(lc.lifecyclename) as "Lifecycle",
rtrim(lcs.statename) as "Queue",
case when ru.registername is null then '' else rtrim(ru.registername) end as "Classic Timer Server",
rtrim(lcs.wftimerservername) as "Core Timer Server"
from hsi.lcstate lcs
inner join hsi.lifecycle lc on lcs.scope = lc.lcnum
left outer join hsi.wfsrvrxlcstate wfsxlcs on lcs.statenum = wfsxlcs.statenum
left outer join hsi.registeredusers ru on wfsxlcs.registernum = ru.registernum
where (ru.registername is not null or lcs.wftimerservername <> '')
order by 1, 2, 3, 4;

-- registered workstations
select hsi.productsold.productname as "Module", hsi.registeredusers.registername as "Workstation"
from hsi.regusersproducts
inner join hsi.registeredusers on hsi.regusersproducts.registernum = hsi.registeredusers.registernum
inner join hsi.productsold on hsi.regusersproducts.producttype = hsi.productsold.producttype
where (hsi.registeredusers.registername is not null)
order by 1, 2;

-- named users
select usernum, username
from hsi.useraccount
where bitand(licenseflag, 1) = 1
order by username
