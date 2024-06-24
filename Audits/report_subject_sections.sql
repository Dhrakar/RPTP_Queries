-- =======================================================================================
--  Audit of Course Sections to dLevels
--
-- Must run as DSDMGR
--
--   This query audits course sections in the SSBSECT table.  It includes results of the 
-- f_new_findAO() and f_section_todept() dsdmgr functions to validate that all of the 
-- sections return valid Academic Organizations and dLevels.
--   The AO codes can be found in DSDMGR.CODE_ACADEMIC_ORGANIZATION
-- 
-- @param &&fiscal_year  The terms ( 'FY-1'03, 'FY'01, 'FY'02  ) to query
-- =======================================================================================
-- headers
SELECT ' ... Audit of section and subject functions' FROM dual;
SELECT '  - only includes subjects not mapping to dlevels' FROM dual;
SELECT
  lpad('Term', 6) || ' | ' ||
  lpad('Campus', 6) || ' | ' ||
  rpad('Subject', 7) || ' | ' ||
  rpad('Description', 31) || ' | ' ||
  lpad('Course', 6) || ' | ' ||
  lpad('Section', 7) || ' | ' ||
  rpad('AC', 3) || ' | ' ||
  rpad('CRN', 5) || ' | ' ||
  rpad('Title', 38) || ' | ' ||
  rpad('Calculated AO', 28) || ' | ' ||
  rpad('Calculated dLevel', 35) || ' | ' ||
  rpad('Calculated FOCUS', 25) || ' | ' ||
  'Attribute Codes'
FROM
  dual
;
-- outer select for simplifying the result_message
SELECT
  lpad(term_code, 6) || ' | ' ||
  lpad(campus, 6) || ' | ' ||
  rpad(subj_code, 7) || ' | ' ||
  rpad(subj_desc, 31) || ' | ' ||
  rpad(crse_no, 6) || ' | ' ||
  rpad(sect_no, 7) || ' | ' ||
  rpad(acct_code, 3) || ' | ' ||
  rpad(crn, 5) || ' | ' ||
  rpad(title, 38) || ' | ' ||
  rpad(calc_ao, 28) || ' | ' ||
  rpad(calc_dlevel, 35) || ' | ' ||
  rpad(calc_focus, 25) || ' | ' ||
  attr_codes AS "xxxxxxxxxx"
FROM (
WITH
  course AS (
    SELECT
      a.scbcrse_subj_code AS subj,
      a.scbcrse_crse_numb AS crse,
      a.scbcrse_title     AS title
    FROM SATURN.SCBCRSE a
    WHERE a.scbcrse_eff_term = (
      SELECT max(b.scbcrse_eff_term )
      FROM SATURN.SCBCRSE b
      WHERE b.scbcrse_subj_code = a.scbcrse_subj_code
        AND b.scbcrse_crse_numb = a.scbcrse_crse_numb
    )  
  )
SELECT DISTINCT
  sec.ssbsect_term_code     AS term_code,
  (
    SELECT SUBSTR(a.stvcamp_desc, 1, 3) || '(' || a.stvcamp_code || ')'
    FROM SATURN.STVCAMP a
    WHERE a.stvcamp_code = sec.ssbsect_camp_code
  )                         AS campus,
  sec.ssbsect_subj_code     AS subj_code,
      (
        SELECT stvsubj_desc
        FROM SATURN.STVSUBJ
        WHERE stvsubj_code = sec.ssbsect_subj_code
      )                     AS subj_desc,
  sec.ssbsect_crse_numb     AS crse_no,
  sec.ssbsect_seq_numb      AS sect_no,
  NVL(
    sec.ssbsect_acct_code,
    '--'
  )                         AS acct_code,
  sec.ssbsect_crn           AS crn,
  NVL2(
    sec.ssbsect_crse_title,
    '(SECT) ' || sec.ssbsect_crse_title,
    '(CRSE) ' || course.title
  )                         AS title,
  '(' 
    || nvl(sec.ssbsect_camp_code,' ')      || ',' 
    || rpad(sec.ssbsect_subj_code, 5, ' ') || ',' 
    || rpad(sec.ssbsect_seq_numb, 3, ' ')  || ',NULL,' 
    || nvl(sec.ssbsect_acct_code, '  ')    || ') => '
    || dsdmgr.f_new_findao (
         sec.ssbsect_camp_code,
         sec.ssbsect_subj_code,
         sec.ssbsect_seq_numb,
         null,
         sec.ssbsect_acct_code
      )                     AS calc_ao,
  '(' 
    || dsdmgr.f_new_findao (
         sec.ssbsect_camp_code,
         sec.ssbsect_subj_code,
         sec.ssbsect_seq_numb,
         null,
         sec.ssbsect_acct_code
      ) || ', '
    || rpad(sec.ssbsect_subj_code, 4, ' ') || ','
    || rpad(sec.ssbsect_crse_numb, 4, ' ') || ','
    || rpad(sec.ssbsect_seq_numb, 3, ' ')  || ','
    || '&&fiscal_year.) => '
    || dsdmgr.f_section_to_dept (
         dsdmgr.f_new_findao (
           sec.ssbsect_camp_code,
           sec.ssbsect_subj_code,
           sec.ssbsect_seq_numb,
           null,
           sec.ssbsect_acct_code
        ),
        sec.ssbsect_subj_code,
        sec.ssbsect_crse_numb,
        sec.ssbsect_seq_numb,
        '&&fiscal_year.'
       )                    AS calc_dlevel,
  '('
    || rpad(sec.ssbsect_crse_numb, 4, ' ') || ') => ' 
    || dsdmgr.f_find_modality (
         sec.ssbsect_crse_numb
       )                    AS calc_focus,
  (
    SELECT DISTINCT listagg( a.ssrattr_attr_code,',') WITHIN GROUP ( ORDER BY SSRATTR_ATTR_CODE )
    FROM SATURN.SSRATTR a
    WHERE a.ssrattr_crn = sec.ssbsect_crn AND a.ssrattr_term_code = sec.ssbsect_term_code
  )                         AS attr_codes
    
FROM
  DSDMGR.ESRPROD_SSBSECT sec
  JOIN course ON (
    course.subj = sec.ssbsect_subj_code
    AND course.crse = sec.ssbsect_crse_numb
  )
WHERE
   sec.ssbsect_term_code IN (
    ( '&&fiscal_year.' - 1) ||  '03', 
      '&&fiscal_year.01', 
      '&&fiscal_year.02'
    )
    -- uncomment to filter by subject
--   AND sec.ssbsect_subj_code = :subj
    -- ------------------------------
    -- Uncomment to filter by specific AO
--   AND 'TV' -- <- Enter AO here
--     = dsdmgr.f_new_findao (
--           sec.ssbsect_camp_code,
--           sec.ssbsect_subj_code,
--           sec.ssbsect_seq_numb,
--           null,
--           sec.ssbsect_acct_code
--        )
   -- -------------------------------
ORDER BY
  sec.ssbsect_term_code,
  sec.ssbsect_crn
)

  -- comment out to get all rows.  Be sure to account
  -- for any AO or subject filters in main query
WHERE
  trim(substr(calc_dlevel, instr(calc_dlevel, '>') - length(calc_dlevel))) IS NULL
  -- ---------------------------
;