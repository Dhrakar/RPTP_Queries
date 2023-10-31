-- =======================================================================================
--    Curriculum Programs
-- 
-- This query returns the programs and associated majors/minors/concentrations for a
-- given term code.  Adapted from code by Mike Earnest
--
-- @param &&fiscal_year  The terms ( 'FY-1'03, 'FY'01, 'FY'02  ) to query
-- =======================================================================================
DEFINE fiscal_year = '2023';
-- the outer select is so that we can filter for just missing calculated dLevels
SELECT 
  *
FROM (
  SELECT DISTINCT
    major.sorcmjr_curr_rule       AS "Curriculum Rule Code",
    major.sorcmjr_cmjr_rule       AS "Major Rule Code",
    major.sorcmjr_term_code_eff   As "Curriculum Term",
    curr.sobcurr_program          AS "Program Code",
    curr.sobcurr_levl_code        AS "Level",
    (
      SELECT substr(a.stvcamp_desc,0,3)
      FROM SATURN.STVCAMP a
      WHERE curr.sobcurr_camp_code = a.stvcamp_code
    )                             AS "Campus",
    curr.sobcurr_coll_code        AS "College Code",
    (
      SELECT a.stvcoll_desc
      FROM SATURN.STVCOLL a
      WHERE curr.sobcurr_coll_code = a.stvcoll_code
    )                             AS "College",
    curr.sobcurr_degc_code        AS "Degree Code",
    ( 
      SELECT a.stvdegc_desc 
      FROM SATURN.STVDEGC a 
      WHERE curr.sobcurr_degc_code = a.stvdegc_code
    )                             AS "Degree",
    major.sorcmjr_stu_ind         AS "STU ind.",
    major.sorcmjr_adm_ind         AS "ADM ind.",
    major.sorcmjr_rec_ind         AS "REC ind.",
    CASE
      WHEN major.sorcmjr_adm_ind = 'N' AND major.sorcmjr_stu_ind = 'N' AND major.sorcmjr_rec_ind ='N' THEN '[0] Not reportable/Non-Degree/Deleted' -- 0
      WHEN major.sorcmjr_adm_ind = 'Y' AND major.sorcmjr_stu_ind = 'N' AND major.sorcmjr_rec_ind ='N' THEN '[1] F/NODA/NDS (possible error)' -- 1
      WHEN major.sorcmjr_adm_ind = 'N' AND major.sorcmjr_stu_ind = 'Y' AND major.sorcmjr_rec_ind ='N' THEN '[2] Pre-major. Admission suspended' -- 2
      WHEN major.sorcmjr_adm_ind = 'Y' AND major.sorcmjr_stu_ind = 'Y' AND major.sorcmjr_rec_ind ='N' THEN '[3] Pre-major. Open for admission and enrollment' -- 3
      WHEN major.sorcmjr_adm_ind = 'N' AND major.sorcmjr_stu_ind = 'N' AND major.sorcmjr_rec_ind ='Y' THEN '[4] Degree only/Teach-out' -- 4
      WHEN major.sorcmjr_adm_ind = 'Y' AND major.sorcmjr_stu_ind = 'N' AND major.sorcmjr_rec_ind ='Y' THEN '[5] (possible error)' -- 5
      WHEN major.sorcmjr_adm_ind = 'N' AND major.sorcmjr_stu_ind = 'Y' AND major.sorcmjr_rec_ind ='Y' THEN '[6] Admission suspended/Teach-out' -- 6
      ELSE '[7] Open for admission, enrollment, and graduation' -- 7
    END                           AS "Calculated Status Flag",  
    major.sorcmjr_majr_code       AS "Major Code",
    mv.stvmajr_valid_major_ind    AS "Major Active?",
    mv.stvmajr_desc               AS "Major",
    substr(mv.stvmajr_cipc_code,1,2)
      || '.'
      || substr(mv.stvmajr_cipc_code,3) AS "Major CIP",
    major.sorcmjr_dept_code       AS "Major Dept. Code",
    (
      SELECT a.stvdept_desc
      FROM SATURN.STVDEPT a
      WHERE a.stvdept_code = major.sorcmjr_dept_code
    )                             AS "Department",
    conc.sorccon_majr_code_conc   AS "Concentration Code",
    ( 
      SELECT c.stvmajr_desc 
      FROM SATURN.STVMAJR c 
      WHERE conc.sorccon_majr_code_conc = c.stvmajr_code 
    )                             AS "Concentration",
    '(' || nvl(curr.sobcurr_camp_code,' ') || ', ' 
     || rpad(curr.sobcurr_degc_code, 4, ' ') || ', ' 
     || rpad(major.sorcmjr_majr_code, 4, ' ') || ', ' 
     || '&&fiscal_year. ) => ' ||
     dsdmgr.f_deg_majr_prog_to_dlevel (
       curr.sobcurr_camp_code,   -- campus_code
       curr.sobcurr_degc_code,   -- degree_code
       major.sorcmjr_majr_code,  -- major_code
       '&&fiscal_year.'          -- fiscal_year
     )                            AS "Calculated dLevel",
    dsdmgr.f_dlevel_to_mau ( 
      dsdmgr.f_deg_majr_prog_to_dlevel (
        curr.sobcurr_camp_code,   -- campus_code
        curr.sobcurr_degc_code,   -- degree_code
        major.sorcmjr_majr_code,  -- major_code
        '&&fiscal_year.'          -- fiscal_year
      )
    )                             AS "Calculated Campus",
    dsdmgr.f_dlevel_to_ao ( 
      dsdmgr.f_deg_majr_prog_to_dlevel (
        curr.sobcurr_camp_code,   -- campus_code
        curr.sobcurr_degc_code,   -- degree_code
        major.sorcmjr_majr_code,  -- major_code
        '&&fiscal_year.'          -- fiscal_year
      )
    )                             AS "Calculated Academic Org."
  FROM
    SATURN.SORCMJR major
    LEFT JOIN SATURN.SOBCURR curr ON (
      curr.sobcurr_curr_rule = major.sorcmjr_curr_rule
    )
    LEFT JOIN SATURN.STVMAJR mv ON (
      mv.stvmajr_code = major.sorcmjr_majr_code
    )
    LEFT JOIN SATURN.SORCCON conc ON (
          major.sorcmjr_term_code_eff = conc.sorccon_term_code_eff
      AND major.sorcmjr_curr_rule = conc.sorccon_curr_rule
      AND major.sorcmjr_cmjr_rule = conc.sorccon_cmjr_rule
    )
  WHERE
    major.sorcmjr_term_code_eff = (
      SELECT max(m2.sorcmjr_term_code_eff)
      FROM SATURN.SORCMJR m2
      WHERE m2.sorcmjr_majr_code = major.sorcmjr_majr_code
    )
    -- comment out to retain programs that show 'N' for all of records/admitting/recruiting
    AND (
      major.sorcmjr_stu_ind = 'Y' OR major.sorcmjr_adm_ind = 'Y' OR major.sorcmjr_rec_ind = 'Y'
    )
    
  ORDER BY
    curr.sobcurr_program,
    major.sorcmjr_majr_code,
    conc.sorccon_majr_code_conc
)
-- Uncomment this where clause to limit to just programs that do not map to dLevels
--WHERE
--  "Calculated dLevel" not LIKE '%=> D%'
ORDER BY
  "Calculated dLevel"
;
