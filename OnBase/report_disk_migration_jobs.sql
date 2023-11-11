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
    ELSE substr( dgm.description, instr(dgm.description,chr(34) || 'f'||chr(34),1, 1) + 5, 8)
  END                  AS "Start Date",
  CASE
    -- check to see if an end date was used for this job
    WHEN instr( dgm.description, chr(34) || 'dates'||chr(34)||':[]',1, 1) > 0 THEN ' --- '
    ELSE substr( dgm.description, instr(dgm.description,chr(34) || 't'||chr(34),1, 1) + 5, 8)
  END                  AS "End Date",
  queued.count         AS "Files Queued"
FROM
  HSI.DGMIGRATORJOB dgm
  LEFT JOIN queued ON queued.job_id = dgm.dgmigratorjobnum
WHERE 
  dgm.status != 4
ORDER BY 
  3, -- disk group
  5  -- start date
;
