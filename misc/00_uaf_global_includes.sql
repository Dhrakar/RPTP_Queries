-- ================================================================================
--     Global Include file for UAF SQL Queries
--
--   This include contains definitions for variables as well as temporary decode
--  tables used to get 'normalized' naming, etc for Banner data.
-- 
--  Use @/<fullpath>/uaf_global_includes.sql as the first line in each script 
-- and then refer to the vars in the code using '&&var' for select/where clauses and  
-- &&var. for use in table/col name substitutions.  Temporary tables will all be 
-- named as tmp$<
-- ================================================================================

-- -------------------------
--  Set up the defaults for
-- formatting output
-- -------------------------
-- If set to off, this supresses showing var substitution
SET verify off
-- If set to off, supresss echoing of commands
SET echo off
SET feedback off
-- page/headers
SET pagesize 0
SET colsep ,
SET headsep off
-- remove extra spaces
SET trimspool on
SET trim on

-- -------------------------
--  Define global variables
-- -------------------------

DEFINE      amp = ''' || chr(38) || '''  -- sets the '&' char
DEFINE      eol = ''' || chr(10) || '''  -- sets the end-of-line char
DEFINE    quote = ''' || chr(39) || '''  -- sets the ' char
DEFINE dblquote = ''' || chr(34) || '''  -- sets the " char

-- for now, spool to /dev/null to avoid noise
spool /dev/null

-- DEFINE global date values 
COLUMN rd                 new_value run_date
COLUMN pd                 new_value prev_date
COLUMN fy                 new_value fiscal_year
COLUMN stvterm_code       new_value current_term
COLUMN stvterm_acyr_code  new_value academic_year
COLUMN stvterm_fa_proc_yr new_value aid_year
  
SELECT 
  curr_term.stvterm_code,       
  curr_term.stvterm_acyr_code, 
  curr_term.stvterm_fa_proc_yr,
  trim( 
    to_char (
      CASE
        WHEN EXTRACT(MONTH FROM SYSDATE) > 6 THEN (EXTRACT(YEAR FROM SYSDATE) + 1)
        ELSE EXTRACT(YEAR FROM SYSDATE)
      END
    )
  ) AS fy,
  trim (
    to_char(
      SYSDATE, 'ddmonyyyy'
    )
  ) AS rd,
  trim (
    to_char (
      SYSDATE - 1, 'ddmonyyyy'
    )
  ) AS pd
FROM 
  SATURN.STVTERM curr_term
WHERE 
  SUBSTR(curr_term.stvterm_code,6,1) IN ('1','2','3') 
  AND curr_term.stvterm_start_date <= SYSDATE
  AND curr_term.stvterm_code = (
    SELECT max(term2.stvterm_code)
    FROM SATURN.STVTERM term2
    WHERE SUBSTR(term2.stvterm_code,6,1) IN ('1','2','3') 
      AND term2.stvterm_start_date <= SYSDATE
  )
;

-- -------------------------
--  Build the normalization 
--  Functions
-- -------------------------

-- returns the PAIR style academic organization titles
-- modified to return non-uaf as well
-- validation table:  dsdmgr.code_academic_organization
CREATE OR REPLACE function f_decode$academic_org ( ao varchar2 )
  return varchar2
IS
  result varchar2(25);
BEGIN
  if      ao = 'UAF' then result := 'UA Fairbanks';
    elsif ao = 'FC' then result := 'Troth Yeddha&&quote';
    elsif ao = 'RB' then result := 'Bristol Bay';
    elsif ao = 'CC' then result := 'Chukchi';
    elsif ao = 'RI' then result := 'Interior Alaska';
    elsif ao = 'KU' then result := 'Kuskokwim';
    elsif ao = 'NW' then result := 'Northwest';
    elsif ao = 'RC' then result := 'Rural College';
    elsif ao = 'TV' then result := 'UAF CTC';
    else                 result := substr('Non-UAF: ' || ao, 0, 24);
  end if;

  return result;

END;
/

-- returns the HR benefits 'buckets' for the benefits for each eClass
CREATE OR REPLACE function f_decode$benefits_category( ecls_code varchar2 )
  return varchar2
IS
  result varchar2(30);
BEGIN
  if      ecls_code = 'A9' then result := 'Faculty';
    elsif ecls_code = 'AR' then result := 'Faculty';
    elsif ecls_code = 'EX' then result := 'Officers/Sr. Administrators';
    elsif ecls_code = 'F9' then result := 'Faculty';
    elsif ecls_code = 'FN' then result := 'Faculty';
    elsif ecls_code = 'FR' then result := 'Officers/Sr. Administrators';
    elsif ecls_code = 'FT' then result := 'Adjunct Faculty';
    elsif ecls_code = 'FW' then result := 'Adjunct Faculty';
    elsif ecls_code = 'CR' then result := 'Staff';
    elsif ecls_code = 'CT' then result := 'Staff';
    elsif ecls_code = 'NR' then result := 'Staff';
    elsif ecls_code = 'NT' then result := 'Staff';
    elsif ecls_code = 'NX' then result := 'Staff';
    elsif ecls_code = 'XR' then result := 'Staff';
    elsif ecls_code = 'XT' then result := 'Staff';
    elsif ecls_code = 'XX' then result := 'Staff';
    elsif ecls_code = 'GN' then result := 'Student';
    elsif ecls_code = 'GT' then result := 'Student';
    elsif ecls_code = 'SN' then result := 'Student';
    elsif ecls_code = 'ST' then result := 'Student';
    else                        result :='Other';
  end if;

  return result;

END;
/

-- This function matches to the BOR structure titles and returns the preferred PAIR titles.
-- It has been updated to return the BOR unit for non-UAF results
-- validation table: dsdmgr.bot_dlevel_to_struc
CREATE OR REPLACE function f_decode$bor_unit ( unit varchar2 )
  return varchar2
IS
  result varchar2(50);
BEGIN
  if      unit = 'UAF Kuskokwim Campus'                          then result := 'College of Rural &&amp Community Development';
    elsif unit = 'UAF Bristol Bay Campus'                        then result := 'College of Rural &&amp Community Development';
    elsif unit = 'UAF Chukchi Campus'                            then result := 'College of Rural &&amp Community Development';
    elsif unit = 'UAF Interior Alaska Campus'                    then result := 'College of Rural &&amp Community Development';
    elsif unit = 'UAF Northwest Campus'                          then result := 'College of Rural &&amp Community Development';
    elsif unit = 'UAF Rural College'                             then result := 'College of Rural &&amp Community Development';
    elsif unit = 'UAF College of Business &&amp Security'        then result := 'UAF College of Business &&amp Security';
    elsif unit = 'UAF Community and Technical College'           then result := 'UAF Community &&amp Technical College';
    elsif unit = 'UAF CEM Engineering &&amp Computer Science'    then result := 'College of Engineering &&amp Mines';
    elsif unit = 'UAF College of Liberal Arts'                   then result := 'College of Liberal Arts';
    elsif unit = 'UAF CNSM Natural Science and Mathematics'      then result := 'College of Natural Science &&amp Mathematics';
    elsif unit = 'UAF CNSM School of Education'                  then result := 'School of Education';
    elsif unit = 'UAF School of Education'                       then result := 'School of Education';
    elsif unit = 'UAF College of Fisheries and Ocean Sciences'   then result := 'College of Fisheries &&amp Ocean Sciences';
    elsif unit = 'UAF School of Fisheries and Ocean Sciences'    then result := 'College of Fisheries &&amp Ocean Sciences';
    elsif unit = 'UAF School of Management'                      then result := 'School of Management';
    elsif unit = 'UAF School of Natural Resources and Extension' then result := 'School of Natural Resources &&amp Extension';
    elsif unit = 'UAF Rasmuson Library'                          then result := 'Rasmuson Library';
    elsif unit = 'UAF Office of the Provost'                     then result := 'Office of the Provost';
    elsif unit = 'UAF Office of the Chancellor'                  then result := 'Office of the Provost';
    elsif unit = 'UAF Summer Sessions and Lifelong Learning'     then result := 'Office of the Provost';
    elsif unit = 'UAF Conferences &&amp Special Events'          then result := 'Office of the Provost';
    elsif unit = 'UAF Cooperative Extension Service'             then result := 'Office of the Provost';
    elsif unit = 'University of Alaska Museum of the North'      then result := 'Museum of the North';
    else                                                              result := substr('Non-UAF: ' || unit, 0, 49);
  end if;

  return result;

END;
/

-- Returns the PAIR style title for the class standing 
-- written as if/then since we can't query the dsdmgr code table
CREATE OR REPLACE function f_decode$class_standing ( stand_code varchar2 )
  return varchar2
IS 
  result varchar2(20);
BEGIN
  if      stand_code = 'GD'          then result := 'Doctoral'; 
    elsif stand_code = 'FF'          then result := 'Freshman (1st Time)';
    elsif stand_code = 'FR'          then result := 'Freshman (Other)';
    elsif stand_code = 'JR'          then result := 'Junior';
    elsif stand_code IN ('ED', 'ES') then result := 'Licensure';
    elsif stand_code IN ('FG', 'GM') then result := 'Master';
    elsif stand_code = 'SR'          then result := 'Senior';
    elsif stand_code = 'SO'          then result := 'Sophomore';
    else                                  result := 'Other';
  end if;
  
  return result;

END;
/

-- Returns the PAIR format for course level numbering
CREATE OR REPLACE function f_decode$course_level ( lvl_code varchar2 )
  return varchar2
IS
  result varchar2(15);
BEGIN
  if      lvl_code = '0' then result := 'Lower Division';
    elsif lvl_code = '1' then result :=  'Lower Division';
    elsif lvl_code = '2' then result :=  'Lower Division';
    elsif lvl_code = '3' then result :=  'Upper Division';
    elsif lvl_code = '4' then result :=  'Upper Division';
    elsif lvl_code = '5' then result :=  'Professional';
    elsif lvl_code = '6' then result :=  'Graduate';
    else                      result := 'Other';
  end if;

  return result;

END;
/

-- returns modified PAIR descriptions for some STVDEGR degree codes. As PL/SQL has weird rules for
-- table access, this requires passing both the code and the description to the function.
-- it returns the modified versions as needed.
CREATE OR REPLACE function f_decode$degree_desc ( degree_code varchar2, degree_desc varchar2 )
  return varchar2
IS
  result varchar2(50);
BEGIN                          -- length 50 = |.........!.........!.........!.........!.........!| 
  if      degree_code = 'BI'   then result := 'Baccalaureate Intended';
    elsif degree_code = 'BEM'  then result := 'Bachelor of Emergency Management';
    elsif degree_code = 'BSEM' then result := 'Bachelor of Security Management';
    elsif degree_code = 'BSRB' then result := 'Bachelor of Sports, Recreation &&amp Business';
    elsif degree_code = 'MAMFA'then result := 'Master of Arts / Master of Fine Arts';
    elsif degree_code = 'MBA'  then result := 'Master of Business Administration';
    elsif degree_code = 'MEE'  then result := 'Master of Electrical Engineering';
    elsif degree_code = 'MNRE' then result := 'Master of Natural Resource Environment';
    elsif degree_code = 'MNRM' then result := 'Master of Natural Resource Management';
    elsif degree_code = 'MSDM' then result := 'Master of Security &&amp Disaster Management';
    elsif degree_code = 'OEC'  then result := 'Occupational Endorsement Certificate';
    else                            result := degree_desc;
  end if;

  return result;

END;
/

-- Returns the PAIR type description for any developmental courses
CREATE OR REPLACE function f_decode$dev_ed ( subj_code varchar2, course_num varchar2 )
  return varchar2
IS
  dgt14 varchar2(4);
  dgt21 varchar2(1);
  dgt22 varchar2(2);
  dgt24 varchar2(4);
  result varchar2(50);
BEGIN
  dgt14 := substr(course_num,1,4);
  dgt21 := substr(course_num,2,1);
  dgt22 := substr(course_num,2,2);
  dgt24 := substr(course_num,2,4);

  if subj_code = 'DEVE' then
    if dgt14 = 'F109' then result := 'ENGL 3 - Nearly College Ready';
    elsif dgt14 IN ('F070','F097','F104','F193','F194') then result := 'ENGL 2 - Some Remediation';
    else result := 'ENGL 1 - Significant Remediation';
    end if;
  elsif subj_code = 'WRTG' then
    if dgt14 = 'F110' then result :=  'ENGL 3 - Nearly College Ready';
    elsif dgt14 = 'F090' then result := 'ENGL 2 - Some Remediation';
    elsif dgt14 = 'F080' then result := 'ENGL 1 - Significant Remediation';
    else result := 'Not Developmental';
    end if;
  elsif subj_code = 'DEVM' then
    if dgt21 = '1' OR dgt14 IN ('F070','F071','F072') then result := 'MATH 3 - Nearly College Ready';
    elsif dgt22 IN ('06','08','09') OR dgt14 = 'F055' then result := 'MATH 2 - Some Remediation';
    else result := 'MATH 1 - Significant Remediation';
    end if;
  elsif subj_code = 'MATH' AND dgt14 >= 'F050' AND dgt14 <= 'F105' then
    if dgt24 IN ('071','105') then result := 'MATH 3 - Nearly College Ready';
    elsif dgt22 = '06' OR dgt24 = '055' then result := 'MATH 2 - Some Remediation';
    else result := 'MATH 1 - Significant Remediation';
    end if;
  elsif subj_code = 'DEVS' then result := 'Study Skills';
  else result := 'Not Developmental';
  end if;

  RETURN result;

END;
/

-- returns the PAIR description for full-time/part-time
CREATE OR REPLACE function f_decode$ftpt ( ftpt_code varchar2 )
  return varchar2
IS
  result varchar2(25);
BEGIN
  if      ftpt_code = 'FTG' then result := 'Full-time Graduate';
    elsif ftpt_code = 'FTU' then result := 'Full-time Undergraduate';
    elsif ftpt_code = 'PTG' then result := 'Part-time Graduate';
    elsif ftpt_code = 'PTU' then result := 'Part-time Undergraduate';
    else                         result := 'XXXXX - Not Assigned';
  end if;

  return result;

END;
/

-- returns the PAIR style campus for a code. Limited to just the UAF
-- codes and is slightly different than STVCAMP
CREATE OR REPLACE function f_decode$home_campus ( stv_code varchar2 )
  return varchar2
IS
  camp_code varchar2(2) := UPPER(stv_code);
  result varchar2(20);
BEGIN
  if      camp_code = 'UAF' then result := 'UA Fairbanks';
    elsif camp_code = '1' then result := 'Rural College';
    elsif camp_code = '2' then result := 'Fairbanks';       -- UAF - Correspondence Study
    elsif camp_code = '3' then result := 'Fairbanks';       -- UAF - Juneau Fisheries 
    elsif camp_code = '5' then result := 'Fairbanks';       -- Ilisagvik 
    elsif camp_code = '6' then result := 'eCampus';
    elsif camp_code = '7' then result := 'Bristol Bay';
    elsif camp_code = '8' then result := 'Interior Alaska';
    elsif camp_code = 'B' then result := 'UAF CTC';         -- UAA - Military Program 
    elsif camp_code = 'F' then result := 'Troth Yeddha&&quote'; 
    elsif camp_code = 'L' then result := 'Kuskokwim';
    elsif camp_code = 'N' then result := 'Northwest';
    elsif camp_code = 'X' then result := 'UAF CTC';
    elsif camp_code = 'Y' then result := 'UAF CTC';         -- UAF - Tanana Valley Campus
    elsif camp_code = 'Z' then result := 'Chukchi'; 
    else                       result := 'Other UA Campus (' || camp_code || ')';
  end if;

  return result;

END;
/

-- This returns if the given course is for eCampus or not.  Many changes to the way eCampus has been defined
-- over the years.
CREATE OR REPLACE function f_decode$is_ecampus ( campus_code varchar2, term_code varchar2, subj_code varchar2, sect_num varchar2 )
  return varchar2
IS
  dgt12 varchar2(2);
  result varchar2(12);
BEGIN
  dgt12 := substr(subj_code,1,2);

  if      dgt12 IN ('US', 'UX')                                                                     then result := 'eCampus';
    elsif term_code <= '201101' AND ( (dgt12 = 'FS') OR ( sect_num >= 'FX0' AND sect_num <= 'FX9')) then result := 'eCampus'; 
    elsif term_code >= '201003' AND ( sect_num >= 'TX0' AND sect_num <= 'TX9')                      then result := 'eCampus';
    elsif term_code >= '201203' AND ( sect_num >= 'KX0' AND sect_num <= 'KX9')                      then result := 'eCampus';
    elsif term_code >= '201301' AND campus_code = '6'                                               then result := 'eCampus';
    else                                                                                                 result := 'Non-eCampus';
  end if;

  return result;

END;
/

-- Returns updated PAIR descriptions for some STVMAJR codes. As PL/SQL has weird
-- table access rules from functions, this function needs both the code and desc
-- from stvmajr and retuns updated ones as needed.
CREATE OR REPLACE function f_decode$major_desc ( major_code varchar2, major_desc varchar2 )
  return varchar2
IS
  result varchar2(60);
BEGIN
  if      major_code = 'LRNM' then result := 'Agriculture &&amp Land Resources Non-Major';
    elsif major_code = 'AHNM' then result := 'Allied Health Non-Major';
    elsif major_code = 'AVMT' then result := 'Aviation Maintenance Technology';
    elsif major_code = 'AVMA' then result := 'Aviation Maintenance';
    elsif major_code = 'CDEV' then result := 'Child Development &&amp Family Studies';
    elsif major_code = 'EVQE' then result := 'Environmental Quality Engineering';
    elsif major_code = 'FSRE' then result := 'Financial Services Representative';
    elsif major_code = 'GEES' then result := 'Geography-Environmental Studies';
    elsif major_code = 'GVMT' then result := 'Ground Vehicle Maintenance Technology';
    elsif major_code = 'HSEM' then result := 'Homeland Security &&amp Emergency Mgmt';
    elsif major_code = 'HRNM' then result := 'Human &&amp Rural Development Non-Major';
    elsif major_code = 'LPEL' then result := 'Licensure Program - Elementary';
    elsif major_code = 'MPRE' then result := 'Mineral Preparation Engineering';
    elsif major_code = 'MAAT' then result := 'Mining Applications &&amp Technologies';
    elsif major_code = 'NRNM' then result := 'Natural Resources Development &&amp Mgmt Non Maj';
    elsif major_code = 'NANM' then result := 'Natural Resources &&amp Agricultural Sciences Non-Major';
    elsif major_code = 'NRMG' then result := 'Natural Resources Mgmt &&amp Geography';
    elsif major_code = 'NRSU' then result := 'Natural Resources &&amp Sustainability';
    elsif major_code = 'PBSE' then result := 'Licensure Program - Post-Bacc K-12 Special Education';
    elsif major_code = 'RWMR' then result := 'Rural Waste Mgmt &&amp Spill Response';
    elsif major_code = 'SHEN' then result := 'Safety, Health &&amp Environmental Awareness Technology';
    elsif major_code = 'SMNM' then result := 'Science, Engineering &&amp Math Non-Major';
    elsif major_code = 'TCSC' then result := 'Teaching Credential - Secondary Education';
    elsif major_code = 'TCFA' then result := 'Teaching Credential - For Alaska';
    elsif major_code = 'WLBC' then result := 'Wildlife Biology &&amp Conservation';
    elsif major_code = '0000' then result := 'General Program';
    elsif major_code = 'XGEN' then result := 'Premajor - General Studies';
    elsif major_code = 'PMEL' then result := 'Premajor - Elementary Education';
    elsif major_code = 'PMNU' then result := 'Premajor - Nursing Qualifications';
    elsif major_code = 'PNRQ' then result := 'Premajor - Nursing Qualifications';
    elsif major_code = 'XCDE' then result := 'Premajor - Child Development &&amp Family Studies';
    elsif major_code = 'XCME' then result := 'Premajor - Computer Engineering';
    elsif major_code = 'XELE' then result := 'Premajor - Electrical Engineering';
    elsif major_code = 'XBAE' then result := 'Premajor - Elementary Education';
    elsif major_code = 'XGEE' then result := 'Premajor - Geography-Environmental Studies';
    elsif major_code = 'XGLE' then result := 'Premajor - Geological Engineering';
    elsif major_code = 'XHSE' then result := 'Premajor - Homeland Security &&amp Emergency Mgmt';
    elsif major_code = 'XMEC' then result := 'Premajor - Mechanical Engineering';
    elsif major_code = 'XNRS' then result := 'Premajor - Natural Resources Mgmt';
    elsif major_code = 'XBAS' then result := 'Premajor - Secondary Education';
    elsif major_code = 'XWLB' then result := 'Premajor - Wildlife Biology &&amp Conservation';
    elsif major_code = 'XEMM' then result := 'Premajor - Emergency Management';
    elsif major_code = 'XAKN' then result := 'Premajor - Alaska Native Studies';
    elsif major_code = 'XPET' then result := 'Premajor - Petroleum Engineering';
    elsif major_code = 'NODQ' then result := 'Non-Degree Seeking';
    elsif major_code = 'NODI' then result := 'Non-Degree Seeking';
    elsif major_code = 'NDSS' then result := 'Non-Degree Seeking';
    elsif major_code = 'NODS' then result := 'Non-Degree Seeking';
    elsif major_code = 'NODA' then result := 'Non-Degree Seeking';
    else                           result := major_desc;
  end if;
  
  return result;
END;
/

-- This function returns the course modality 
CREATE OR REPLACE function f_decode$modality ( sess_code varchar2 )
  return varchar2
IS
  result varchar2(15);
BEGIN
  /*
   * New Session codes rubrick
   *  Code | Title                               | Description
   *   F   | In-Person / Face-to-face            | Instruction is face to face at a physical location
   *   O   | Online - No Set Time / Asynchronous | Instruction occurs completely online with no mandatory set meeting time
   *   C   | In-Person AND Online                | Combination of Face-to-face and online intruction
   *   U   | In-Person OR Online                 | Students can participate in scheduled class sessions in person or online
   *   S   | Online - Set Time / Synchronous     | Instruction occurs completely online at a set time
   */
  if      sess_code IN ('0')      then result := 'Distance';
    elsif sess_code IN ('1', '2') then result := 'Hybrid';
    elsif sess_code IN ('3')      then result := 'Face-to-Face';
    elsif sess_code IN ('F')      then result := 'Face-to-Face';
    elsif sess_code IN ('O')      then result := 'Distance';
    elsif sess_code IN ('C')      then result := 'Hybrid';
    elsif sess_code IN ('U')      then result := 'Hybrid';
    elsif sess_code IN ('S')      then result := 'Distance';
    else                               result := 'Face-to-Face';
  end if;

  return result;

END;
/

-- Returns the Campus/MAU name for FTVORGN level1 'dlevel' orgn code
CREATE OR REPLACE function f_decode$orgn_campus ( dlevel varchar2 )
  return varchar2
IS
  result varchar2(5);
BEGIN
  if      dlevel = 'UAATOT' then result := 'UAA';
    elsif dlevel = 'UAFTOT' then result := 'UAF';
    elsif dlevel = 'UASTOT' then result := 'UAS';
    elsif dlevel = 'SWTOT'  then result := 'SW';
    elsif dlevel = 'EETOT'  then result := 'EE';
    elsif dlevel = 'FDNTOT' then result := 'FDN';
    elsif dlevel = 'UATKL'  then result := 'TKL';
    else                         result := 'ZZZ';
  end if;

  return result;

END;
/

-- Returns the PAIR preferred format for student race as derived from the dsdmgr.code_race table
CREATE OR REPLACE function f_decode$race ( race_code varchar2) 
  return varchar2
IS
  result varchar2(20);
BEGIN
  if      race_code IN ('1', 'AA', 'AE', 'AH', 'AI', 'AK', 'AM', 'AN', 'AQ', 'AS', 'AT', 'AY', 'IN', 'XX') then result := 'AK Native/Am Indian';
    elsif race_code IN ('2', 'SI', 'SF') then result := 'Asian';
    elsif race_code IN ('3', 'BL') then result := 'Black';
    elsif race_code IN ('4', 'NH') then result := 'Pacific Islander';
    elsif race_code IN ('5', 'WH') then result := 'White';
    else                                result := 'Unknown';
  end if;

  return result;

END;
/

-- Returns the PAIR style Semester string from term code ( YYYYTT )
CREATE OR REPLACE function f_decode$semester ( term_code varchar2 )
  return varchar2
IS
  t_year varchar2(4);
  t_term varchar2(2);
  result varchar2(11);
BEGIN
  t_year := substr(term_code,1,4);
  t_term := substr(term_code,5,2);

  if      t_term = '01' then result := 'Spring ' || t_year;
    elsif t_term = '02' then result := 'Summer ' || t_year;
    else  result := 'Fall ' || t_year;
  end if;

  return result;
  
END;
/

-- This returns the UAF OMB fund categories for the type of distribution
CREATE OR REPLACE function f_decode$uaf_fund_type ( fund_code varchar2 )
  return varchar2
IS
  result varchar2(15);
BEGIN
  if      fund_code between 100000 and 139999 then result := 'UNRESTRICTED';
    elsif fund_code between 140000 and 149999 then result := 'MATCH';
    elsif fund_code between 150000 and 169999 then result := 'UNRESTRICTED';
    elsif fund_code between 170000 and 179999 then result := 'RECHARGE';
    elsif fund_code between 180000 and 189999 then result := 'UNRESTRICTED';
    elsif fund_code between 190000 and 199999 then result := 'AUXILIARY';
    elsif fund_code between 200000 and 999999 then result := 'RESTRICTED';
    else                                           result := 'ERROR';
  end if;

  return result;

END;
/

-- returns the UA In Review 'buckets' for each eClass
CREATE OR REPLACE function f_decode$uar_employee_category ( ecls_code varchar2 )
  return varchar2
IS
  result varchar2(10);
BEGIN
  /*
   * UA In Review 'buckets' for the employee classes.
   * Used for employee FTE and headcount categories.
   */
  if      ecls_code in ('A9', 'F9', 'FN', 'FR') then result := 'Faculty';
    elsif ecls_code in ('CR', 'EX', 'NR', 'XR') then result := 'Staff';
    else                                             result := 'Other';
  end if;

  return result;

END;
/

-- -----------------------
--  Grants 
-- -----------------------
GRANT EXECUTE ON f_decode$academic_org          TO dsduser;
GRANT EXECUTE on f_decode$benefits_category     TO dsduser;
GRANT EXECUTE ON f_decode$bor_unit              TO dsduser;
GRANT EXECUTE ON f_decode$class_standing        TO dsduser;
GRANT EXECUTE ON f_decode$course_level          TO dsduser;
GRANT EXECUTE ON f_decode$degree_desc           TO dsduser;
GRANT EXECUTE ON f_decode$dev_ed                TO dsduser;
GRANT EXECUTE ON f_decode$ftpt                  TO dsduser;
GRANT EXECUTE ON f_decode$home_campus           TO dsduser;
GRANT EXECUTE ON f_decode$is_ecampus            TO dsduser;
GRANT EXECUTE ON f_decode$major_desc            TO dsduser;
GRANT EXECUTE ON f_decode$modality              TO dsduser;
GRANT EXECUTE ON f_decode$orgn_campus           TO dsduser;
GRANT EXECUTE ON f_decode$race                  TO dsduser;
GRANT EXECUTE ON f_decode$semester              TO dsduser;
GRANT EXECUTE ON f_decode$uaf_fund_type         TO dsduser;
GRANT EXECUTE ON f_decode$uar_employee_category TO dsduser;

-- stop the fake spooling
spool off;

-- no EXIT specified here since this file is included in other queries
-- EXIT;
-- /
