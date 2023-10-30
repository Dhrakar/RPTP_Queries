-- =============================================================================
-- UAF Staffing/Employee Trends project 
--
--  Based on DSDMGR tables & RPTP FTVORGN_LEVELS for consistency with PAIR and
-- SW IR reports (like UA in Review).  Grabs the last 10 FYs worth of data.
--  
-- This report is headcount only
--  
-- History
--  - 20170430 Converted from other queries (to remove org stuff in favor
--             of having the orgs in a separate table.
--  - 20170929 migrate to separate file
--  - 20180424 add ABS categorization and mush ext temp into temp
--  - 20180925 Added UA in Review difinition for Faculty/Staff
--             Removed MAU column (always UAF since filtered to level2 UAFTOT)
--             Moved check for level2 = 'UAFTOT' to be in FTVORGN_LEVELS join
--  - 20230111 Updated some decode statements with dsduaf functions
--             Revised cabinet/unit/costcenter/department titles to use function
-- =============================================================================
SELECT DISTINCT
  -- // Uncomment when exporting to database
  -- ''                             AS "Row ID",
  -- // ================================================
  emp.employee_id                AS "UAID",
  emp.emp_pidm                   AS "ID",
  dsduaf.f_decode$semester(
    emp.term_code
  )                              AS "TERM", 
  emp.fiscal_year                AS "FY",
  emp.department_code            AS "Org Code",
  camp.description               AS "Academic Organization",
  -- // comment out when running for database
  -- org.title1                     AS "Campus",
  CASE  -- cabinet was at level 3 up until FY20. Use the term to decide between level 2 and 3
    WHEN emp.term_code < 201903 THEN
      reports.f_orgn_title(
        'B', reports.ua_f_orgn_hier1_fnc(
          'B', org.orgn_code, 3, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
        )
      )  
    ELSE 
      reports.f_orgn_title(
        'B', reports.ua_f_orgn_hier1_fnc(
          'B', org.orgn_code, 2, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
        )
      ) 
  END                            AS "Cabinet",
  CASE   -- unit was at level 4 up until FY20. Use the term to decide between level 3 and 4
    WHEN emp.term_code < 201903 THEN
      reports.f_orgn_title(
        'B', reports.ua_f_orgn_hier1_fnc(
          'B', org.orgn_code, 4, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
        )
      )
    ELSE
      reports.f_orgn_title(
        'B', reports.ua_f_orgn_hier1_fnc(
          'B', org.orgn_code, 3, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
        )
      )
  END                            AS "Unit",
  CASE   -- cost center was at level 5 up until FY20. Use the term to decide between level 4 and 5
    WHEN emp.term_code < 201903 THEN
      reports.f_orgn_title(
        'B', reports.ua_f_orgn_hier1_fnc(
          'B', org.orgn_code, 5, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
        )
      )
    ELSE
      reports.f_orgn_title(
        'B', reports.ua_f_orgn_hier1_fnc(
          'B', org.orgn_code, 4, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
        )
      )
  END                            AS "Cost Center",
  reports.f_orgn_title(
    'B', org.orgn_code, to_date(substr(emp.term_code, 1,4) || '/0' || (5 + substr(emp.term_code, 5,2)) || '/01', 'YYYY/MM/DD')
  )                              AS "Department",
  -- //================================================
  emp.name_first 
    || ' ' 
    || emp.name_last             AS "Name", 
  CASE WHEN emp.gender = 'M' 
         THEN 'Male'
       WHEN emp.gender = 'F'
         THEN 'Female'
       ELSE 'Not Reported' 
  END                            AS "Gender",
  CASE -- mash the extended temp and temp statuses together
    WHEN emp.regular_temporary_status = 'REGULAR' 
    THEN emp.regular_temporary_status
    ELSE 'TEMPORARY'
  END                            AS "Regular or Temp",
  emp.ft_pt_status               AS "Full or Part Time",
  emp.contract_class             AS "Contract Class",
  emp.job_class_primary_code     AS "Position Class",
  dsduaf.f_decode$benefits_category(
    emp.job_class_primary_code
  )                              AS "ABS Description",
  -- this col matches the ECLS list used to generate UA in Review
  dsduaf.f_decode$uar_employee_category(
    emp.job_class_primary_code
  )                              AS "UA Review Category",
  eeo.eeo_occupation_desc        AS "EEO Description",
  emp.salary_annualized_12       AS "Annualized 12 Month Salary"
FROM
  DSDMGR.H_EMPLOYEE emp
  JOIN DSDMGR.CODE_EEO_OCCUPATION eeo ON 
    emp.occupation_eeo_primary_code = eeo.eeo_occupation_code
  JOIN REPORTS.FTVORGN_LEVELS org ON (
        emp.department_code = org.orgn_code
     -- limit to UAF employees
    AND org.level1 IN ( 'UAFTOT')
  )
  LEFT JOIN DSDMGR.CODE_ACADEMIC_ORGANIZATION camp ON 
    emp.academic_org_code = camp.academic_organization_code
WHERE
  -- this section dynamically gets the last 5 fiscal years of freeze data
  -- it uses the fall term and grabs anything between this year's fall and the
  -- 10 years-ago fall term
  emp.term_code BETWEEN  
        (EXTRACT(year FROM CURRENT_DATE) - 5) || '03'
    AND EXTRACT(year FROM CURRENT_DATE) || '03'
ORDER BY
 emp.fiscal_year, "TERM"
;