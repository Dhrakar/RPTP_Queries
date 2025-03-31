-- ===============================================================
--  Disk Group Migration Report
-- 
-- Gives a count of all of the documents files that are queued up
-- for migration in each job.
-- ===============================================================
WITH
  queued AS (
    SELECT
      a.dgmigratorjobnum        AS job_id,
      a.diskgroupnum            AS disk_grp,
      count(a.dgmqueuedfilenum) AS count
    FROM HSI.DGMQUEUEDFILE a
    GROUP BY
      a.dgmigratorjobnum,
      a.diskgroupnum
  )
SELECT
  dgm.dgmigratorjobnum AS "Job #",
  DECODE (
    dgm.status,
    '-1', 'Queueing',
    '0', 'Paused',
    '1', 'Active',
    '2', 'Finished',
    '3', 'Finished w/Errors',
    '4', 'Deleted',
    dgm.status
  )                   AS "Status",
  (
    SELECT trim(diskgroupname) 
    FROM HSI.DISKGROUP 
    WHERE diskgroupnum = to_number (
      substr( 
        dgm.description,
        instr(dgm.description,'dgs',1, 1) + 6,
        3 -- just assume we will have 3 digit DG IDs for now
      )
    )
  )                    AS "Source",
  (
    SELECT trim(diskgroupname) 
    FROM HSI.DISKGROUP 
    WHERE diskgroupnum = dgm.destdiskgroupnum 
  )                    AS "Destination",
  CASE
    -- check to see if a start date was used for this job
    WHEN instr( dgm.description, chr(34) || 'dates'||chr(34)||':[]',1, 1) > 0 THEN ' --- '
    ELSE substr(substr( dgm.description, instr(dgm.description,chr(34) || 'f'||chr(34),1, 1) + 5, 8), 5,2)
         || '/'
         || substr(substr( dgm.description, instr(dgm.description,chr(34) || 'f'||chr(34),1, 1) + 5, 8), 7, 2)
         || '/' 
         || substr(substr( dgm.description, instr(dgm.description,chr(34) || 'f'||chr(34),1, 1) + 5, 8), 0, 4)
  END                  AS "Start Date",
  CASE
    -- check to see if an end date was used for this job
    WHEN instr( dgm.description, chr(34) || 'dates'||chr(34)||':[]',1, 1) > 0 THEN ' --- '
    ELSE substr(substr( dgm.description, instr(dgm.description,chr(34) || 't'||chr(34),1, 1) + 5, 8), 5,2)
         || '/'
         || substr(substr( dgm.description, instr(dgm.description,chr(34) || 't'||chr(34),1, 1) + 5, 8), 7, 2)
         || '/' 
         || substr(substr( dgm.description, instr(dgm.description,chr(34) || 't'||chr(34),1, 1) + 5, 8), 0, 4)
  END                  AS "End Date",
  CASE
    -- check to see if doc type filters were used
    WHEN substr( dgm.description, instr(dgm.description,'dts',1, 1) + 5,2) = '[]' THEN ' --- '
    ELSE substr( dgm.description, instr(dgm.description,'dts',1, 1) + 6, instr(dgm.description,'],' || chr(34) || 'x'||chr(34),1, 1) - (instr(dgm.description,'dts',1, 1) + 6))
  END                  AS "Document Types",
  queued.count         AS "Files Queued"
FROM
  HSI.DGMIGRATORJOB dgm
  LEFT JOIN queued ON queued.job_id = dgm.dgmigratorjobnum
--WHERE 
--  dgm.status != 4
--  -- optional filter for source
--  AND to_number (
--      substr( 
--        dgm.description,
--        instr(dgm.description,'dgs',1, 1) + 6,
--        3 -- just assume we will have 3 digit DG IDs for now
--      )
--    ) = 111
  -- optional filter for destination
  -- AND dgm.destdiskgroupnum = 157
ORDER BY 
  3, -- disk group
  1 desc  -- job #
;

-- Get information about the queued files in a job
-- useful for figuring out which document belongs to error files
SELECT DISTINCT
  qf.dgmqueuedfilenum AS queue_id,
  qf.dgmigratorjobnum AS job_id,
  qf.diskgroupnum     AS disk_grp,
  idp.filetypenum     AS file_type,
  substr(ff.errordescription, 0, 50) AS file_err,
  idp.filepath        AS file_name,
  idp.filesize        AS file_size,
  idp.itemnum         AS doc_handle,
  DECODE (
    doc.status,
    0, 'Indexed',
    1, 'Awaiting Index',
    16, 'Deleted',
    'Status: ' || doc.status
  )                   AS doc_status,
  trim(
    replace( 
      replace( 
        replace(
          doc.itemname,'/',''
        ),'<red>', '' 
      ),'<blue>', '' 
    )
  )                   AS doc_name,
  idp.batchnum
    ||' => ' 
    || trim(bq.queuename) 
    || ' Status: ' || bq.status 
    || ' Date: ' || bq.datestarted
                      AS batch_info
FROM
  HSI.DGMQUEUEDFILE qf
  LEFT JOIN HSI.DGMFAILEDFILE ff ON (
    ff.dgmigratorjobnum = qf.dgmigratorjobnum
  )
  INNER JOIN HSI.ITEMDATAPAGE idp ON (
    trim(qf.filepath) = trim(idp.filepath)
  )
  INNER JOIN HSI.ITEMDATA doc ON (
    doc.itemnum = idp.itemnum
  )
  LEFT JOIN HSI.ARCHIVEDQUEUE bq ON (
    bq.batchnum = idp.batchnum
  )
WHERE 
  qf.dgmigratorjobnum = :job_no
ORDER BY
  idp.itemnum,
  idp.filepath
;

-- this query shows a summary of all of the doctypes and numbers of documents for a disk group
SELECT
  (
    SELECT trim(diskgroupname) 
    FROM HSI.DISKGROUP 
    WHERE diskgroupnum = idp.diskgroupnum 
  )                     AS diskgrp,
  trim(dt.itemtypename) AS doc_type,
  count(idp.itemnum) as dochandle_count
FROM
  HSI.ITEMDATAPAGE idp
  JOIN HSI.ITEMDATA itd ON (
    itd.itemnum = idp.itemnum
  )
  JOIN HSI.DOCTYPE dt ON (
    itd.itemtypenum = dt.itemtypenum
  )
  LEFT JOIN HSI.ARCHIVEDQUEUE bq ON (
    bq.batchnum = idp.batchnum
  )
WHERE
  -- Unencrypted disk groups 
  -- 101 => System ( will stay unencrypted to avoid issues)
  -- 102 => Admissions
  -- 105 => AnchorageADscan
  -- 106 => AnchorageFAscan
  -- 107 => JunoFAscan
  -- 108 => JunoADscan
  -- 111 => Registrar
  -- 112 => JunoROscan
  -- 113 => AnchorageROscan
  -- 117 => SystemUAA
  -- 118 => SystemUAS
  -- 119 => LFConversion
  -- 121 => RIM
  -- 124 => EnrMgmtUAS
  -- 122 => HumanResources
  -- 126 => Test DDI
  -- 129 => FINSW
  -- 131 => FINUAA
  -- 133 => UA Scholars
  -- 135 => SORS
  -- 138 => SystemGovernance
  idp.diskgroupnum between 100 and 200
group by 
  idp.diskgroupnum,
  trim(dt.itemtypename)
order by
  trim(dt.itemtypename)
;

-- this query shows details of all of the doctypes and numbers of documents for a disk group
SELECT
  (
    SELECT trim(diskgroupname) 
    FROM HSI.DISKGROUP 
    WHERE diskgroupnum = idp.diskgroupnum 
  )                     AS diskgrp,
  trim(dt.itemtypename) AS doc_type,
  trim(
    replace( 
      replace( 
        replace(
          itd.itemname,'/',''
        ),'<red>', '' 
      ),'<blue>', '' 
    )
  )                      AS auto_name,
  DECODE (
    itd.status,
    0, 'Indexed',
    1, 'Awaiting Index',
    16, 'Deleted',
    'Status: ' || itd.status
  )                      AS doc_status,
  idp.filepath           AS file_path,
  to_char(itd.itemdate, 'YYYYMMDD') AS docdate_yyyymmdd,
  to_char(itd.datestored, 'MM/DD/YYYY') AS uploaded_on,
  itd.itemnum           AS doc_handle,
  idp.batchnum
    ||' => ' 
    || trim(bq.queuename) 
    || ' Status: ' || bq.status 
    || ' Date: ' || bq.datestarted
                      AS batch_info
--  count(idp.itemnum) as dochandle_count
FROM
  HSI.ITEMDATAPAGE idp
  JOIN HSI.ITEMDATA itd ON (
    itd.itemnum = idp.itemnum
  )
  JOIN HSI.DOCTYPE dt ON (
    itd.itemtypenum = dt.itemtypenum
  )
  LEFT JOIN HSI.ARCHIVEDQUEUE bq ON (
    bq.batchnum = idp.batchnum
  )
WHERE
  -- Unencrypted
  -- 101 => System ( will stay unencrypted to avoid issues)
  -- 102 => Admissions
  -- 111 => Registrar
  -- 119 => LFConversion
  -- 121 => RIM
  -- 124 => EnrMgmtUAS
  -- 122 => HumanResources
  -- 129 => FINSW
  -- 133 => UA Scholars
  -- 135 => SORS
  -- encrypted
  -- 149 => Bursar
  -- 152 => UA_ADMISSIONS
  -- 157 => UA_REGISTRAR
  
  idp.diskgroupnum IN ( 101, 102, 111, 119, 121, 122, 124, 129, 133, 135 )
  -- only look for non-system doc types inadvertantly put into the system drive
  AND dt.itemtypename NOT LIKE 'SYS %'
  -- uncomment out to limit b date range
  -- AND itd.itemdate < to_date('01/01/2000', 'MM/DD/YYYY')
--group by 
--  idp.diskgroupnum,
--  trim(dt.itemtypename)
order by
--  to_char(itd.itemdate, 'YYYYMMDD'),
  trim(dt.itemtypename)
;

select * from HSI.DISKGROUP;
select * from HSI.DGMIGRATORJOB;
select * from HSI.DGMQUEUEDFILE;
select * from HSI.doctype where diskgroupnum = 119;
select * from hsi.archivedqueue;
select * from hsi.itemdata where itemnum = 3517740;
select * from hsi.itemdata where itemdate < to_date('01/01/2000', 'MM/DD/YYYY');
select * from hsi.itemdatapage;
select * from hsi.eventlog where messagetext like '%delete%';