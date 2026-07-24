WITH
  users AS (
  SELECT distinct
  a.email,
  b.goremal_pidm as pidm
  FROM
  FNDLB.ALASKAX a
  LEFT JOIN GENERAL.GOREMAL b ON upper(b.goremal_email_address) = upper(a.email)
  ),
  employee_base AS (
  --// Core table of the employee information
  SELECT DISTINCT
    emp.spriden_pidm          AS pidm,
    emp.spriden_id            AS uaid,
    usr.gobtpac_external_user AS uaname,
    ban.gobeacc_username      AS bannerid,
    emp.spriden_last_name || ', ' 
      || coalesce(bio.spbpers_pref_first_name, emp.spriden_first_name) || ' ' 
      || substr(emp.spriden_mi,1,1) AS full_name,
    usr.gobtpac_external_user || '@alaska.edu' AS email,
    ua.pebempl_orgn_code_home AS dlevel,
    ua.pebempl_orgn_code_dist AS tkl,
    decode (
      ua.pebempl_empl_status,
      'A', 'Active: ' || to_char( ua.pebempl_current_hire_date, 'DD-MON-yy'),
      'T', '  Term: ' || to_char( ua.pebempl_term_date, 'DD-MON-yy'),
      '?'
    )                         AS status,
    CASE
      -- Use the preferred Gender if available, otherwise sex
      WHEN bio.spbpers_gndr_code IS NOT NULL THEN
        DECODE (
          bio.spbpers_gndr_code,
          'A',	 'Agender',
          'DNA', 'Does Not Apply',
          'F',	 'Female',
          'GQ',	 'Genderqueer',
          'M',	 'Male',
          'N',	 'Non-Binary',
          'TF',	 'Transgender Female',
          'TM',	 'Transgender Male',
          bio.spbpers_gndr_code
        )
      ELSE 
        DECODE (
          bio.spbpers_sex,
          'F',	'Female',
          'M',	'Male',
          'N',	'Not Disclosed',
          bio.spbpers_sex
        )
      END                     AS gender
    FROM SATURN.SPRIDEN emp
    INNER JOIN SATURN.SPBPERS  bio ON emp.spriden_pidm = bio.spbpers_pidm
    INNER JOIN GENERAL.GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
    LEFT JOIN PAYROLL.PEBEMPL ua  ON emp.spriden_pidm = ua.pebempl_pidm
    LEFT JOIN GENERAL.GOBEACC ban  ON emp.spriden_pidm = ban.gobeacc_pidm
    WHERE emp.spriden_change_ind IS NULL
  ),
  records AS ( 
  -- // Ranked CTE of all current graduate student records that are 
  -- // effective as of or before the current term
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
    a.sgbstdn_astd_code        AS astd_code,
    -- rank each of the student records to get the most current
    ROW_NUMBER() OVER (
      PARTITION BY a.sgbstdn_pidm
      ORDER BY a.sgbstdn_term_code_eff DESC
    ) AS row_no
  FROM 
    SATURN.SGBSTDN a
  WHERE
      a.sgbstdn_term_code_eff <= '202602'
  )
SELECT DISTINCT
  substr(org.level1, 0, length(org.level1) - 3) AS "Campus",
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit", 
  org.title                   AS "Department",
  emp.uaid                    AS "UA ID",
  emp.full_name               AS "Full Name",
  CASE 
    WHEN emp.status = '?' AND records.pidm IS NOT NULL THEN 'Student: ' ||  records.campus || ', ' || records.prim_college_desc
    WHEN emp.status = '?' AND records.pidm IS NULL THEN 'Student??'
    ELSE emp.status END AS "UA Status",
  users.email                 AS "FactBook Email"
FROM
  users
  left join employee_base emp ON emp.pidm = users.pidm
  left join REPORTS.FTVORGN_LEVELS org ON org.orgn_code = emp.dlevel 
  left join records on records.pidm = users.pidm and records.row_no = 1
ORDER BY 1,2,3,4,5
;
      