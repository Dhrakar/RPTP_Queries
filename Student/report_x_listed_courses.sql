-- ============================================================================
--  Generates a list of all cross-listed courses for UAF for the current term
-- ============================================================================
WITH
  terms AS ( 
  SELECT 
    max(a.stvterm_code) AS curr_term
  FROM 
    SATURN.STVTERM a
  WHERE 
        substr(a.stvterm_code,6,1) IN ('1','2','3') 
    AND a.stvterm_start_date <= SYSDATE
)
select distinct
  a.ssbxlst_xlst_group,
  listagg (
    b.ssrxlst_crn, ','
  ) within group (
    order by b.ssrxlst_crn
  ) AS "Courses"
from
  saturn.ssbxlst a
  left join saturn.ssrxlst b ON (
    b.ssrxlst_term_code = a.ssbxlst_term_code
    and b.ssrxlst_xlst_group = a.ssbxlst_xlst_group
  )
where
  a.ssbxlst_term_code = '202403'
group by
  a.ssbxlst_xlst_group
;
  
