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
  substr( 
        dgm.description,
        instr(dgm.description,'f',1, 1) + 4,
        8
      )                AS "Start Date",
  substr( 
        dgm.description,
        instr(dgm.description,'t',1, 2) + 4,
        8
      )                AS "End Date",
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
