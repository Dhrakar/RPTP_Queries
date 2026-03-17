with
  records AS ( 
  -- buils temp table of all current graduate student records that are 
  -- effective as of or before the current term
  SELECT 
    a.sgbstdn_term_code_eff    AS term_eff,
    a.sgbstdn_camp_code        AS campus,
    a.sgbstdn_pidm             AS pidm,
    a.sgbstdn_degc_code_1      AS prim_degree_code,
    (
      SELECT stvdegc_desc
      FROM SATURN.STVDEGC 
      WHERE stvdegc_code = a.sgbstdn_degc_code_1
    )                          AS prim_degree_desc,
    a.sgbstdn_majr_code_1      AS prim_major_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_1
    )                          AS prim_major_desc,
    (
      SELECT substr(stvmajr_cipc_code, 0,2) || '.' || substr(stvmajr_cipc_code, 3, 4)
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_1
    )                          AS prim_major_cip_code,
    a.sgbstdn_majr_code_conc_1 AS prim_conc_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_conc_1
    )                          AS prim_conc_desc,
    a.sgbstdn_coll_code_1      AS prim_college_code,
    (
      SELECT stvcoll_desc 
      FROM SATURN.STVCOLL
      WHERE stvcoll_code = a.sgbstdn_coll_code_1
    )                          AS prim_college_desc,
    a.sgbstdn_program_1        AS prim_program_code,
    a.sgbstdn_degc_code_2      AS sec_degree_code,
    (
      SELECT stvdegc_desc
      FROM SATURN.STVDEGC 
      WHERE stvdegc_code = a.sgbstdn_degc_code_2
    )                          AS sec_degree_desc,
    a.sgbstdn_majr_code_2      AS sec_major_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_2
    )                          AS sec_major_desc,
    (
      SELECT substr(stvmajr_cipc_code, 0,2) || '.' || substr(stvmajr_cipc_code, 3, 4)
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_2
    )                          AS sec_major_cip_code,
    a.sgbstdn_majr_code_conc_1 AS sec_conc_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_conc_2
    )                          AS sec_conc_desc,
    a.sgbstdn_coll_code_2      AS sec_college_code,
    (
      SELECT stvcoll_desc 
      FROM SATURN.STVCOLL
      WHERE stvcoll_code = a.sgbstdn_coll_code_2
    )                          AS sec_college_desc,
    a.sgbstdn_program_2        AS sec_program_code,
    a.sgbstdn_levl_code        AS levl_code,
    a.sgbstdn_resd_code        AS resd_code,
    a.sgbstdn_astd_code        AS astd_code
  FROM 
    SATURN.SGBSTDN a
  WHERE
      -- limit to just UAF graduate students
    a.sgbstdn_levl_code LIKE '%F'
      -- limit to just the current student record
    AND (
      a.sgbstdn_term_code_eff = (
        SELECT MAX(i.sgbstdn_term_code_eff)
        FROM SATURN.SGBSTDN i
        WHERE a.sgbstdn_pidm = i.sgbstdn_pidm
          AND i.sgbstdn_term_code_eff <= '202601'
      )
    )    
  ),
  registered AS (  
    -- build temp table of all the courses students registered
    SELECT 
      reg.sfrstcr_pidm           AS pidm,
      listagg( distinct
        reg.sfrstcr_term_code || ': ' || a.ssbsect_subj_code || a.ssbsect_crse_numb, ', '
      ) within group (
        order by reg.sfrstcr_term_code
      )                          AS courses
    FROM
      SATURN.SFRSTCR reg
      -- limit to just the records we found in sgbstdn
      INNER JOIN records ON records.pidm = reg.sfrstcr_pidm
      -- status for each couse's registration
      INNER JOIN SATURN.STVRSTS enr ON (
            reg.sfrstcr_rsts_code = enr.stvrsts_code
        AND enr.stvrsts_voice_type = 'R'
      )  
      -- courses this student is/was registered for
      LEFT JOIN SATURN.SSBSECT a ON (
            a.ssbsect_term_code = reg.sfrstcr_term_code
        AND a.ssbsect_crn = reg.sfrstcr_crn
      )
    group by
      reg.sfrstcr_pidm
  )
select distinct
  b.email                     AS "AlaskaX Address",
  a.goremal_pidm AS pidm,
  stu.spriden_id              AS "UA ID",
  stu.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        stu.spriden_first_name 
       )
    || ' ' 
    || substr ( stu.spriden_mi,1,1)                      
                              AS "Full Name",
  records.prim_degree_code    AS "Primary Degree",
  records.prim_major_code     AS "Primary Major",
  records.levl_code           AS "Level Code",
  registered.courses          AS "Enrolled Courses"
from 
  GENERAL.GOREMAL a
  JOIN FNDLB.ALASKAX b ON b.email = a.goremal_email_address
  JOIN records ON records.pidm = a.goremal_pidm
  JOIN registered ON registered.pidm = a.goremal_pidm
  JOIN saturn.spriden stu on (
    stu.spriden_pidm = a.goremal_pidm
    and stu.spriden_change_ind is null
  )
  JOIN SATURN.SPBPERS bio  ON (
    bio.spbpers_pidm = a.goremal_pidm
  )
order by
  stu.spriden_id
;