spool f_nchems_summary_sorted.lst 
-- ========================================================================
-- f_nchems_summary_sorted()
--
-- purpose
--  Returns the NCHEMS category description for the program description and
-- codes.  Differs from f_nchems_summary() in that this can optionally 
-- include numbers for sorting the descriptions. Note that this is based on
-- the NCHEMS code from Harmonie Peters from 2020 as well as the BOR 
-- f_nchems_sb() function.  Note that for fy < 2020, there are no numbers for
-- the category buckets and the results only rely on the fy and nchem_code. 
-- the categories are also a bit different when looking < 2020.
--
--
-- ========================================================================

-- function
create or replace function f_nchems_summary_sorted (
                                                     nchem_code varchar2,
                                                     nchem_desc varchar2,
                                                     alloc_desc varchar2,
                                                     fy         varchar2,
                                                     sort       varchar2
                                                   )
-- This function returns the descriptive NCHEMS categorization for the 
-- program information.  The FY20+ code is based on SPBMGR.F_NCHEMS_SUMMARY()
-- for all of the mappings.  The pre FY20 is historical to IR.  The FY and
-- sorting flag are added here since we have multiple methods for the function.
-- The sorting order when sort = 'Y' is historical from previous IR functions 
-- and is not related to the nchem code values.
-- 
-- Parameters
--  nchem_code  level3 in the Program hierarchy (ftvprog)
--  nchem_desc  title3 in the Program hierarchy (ftvprog)
--  alloc_desc  title2 in the Program hierarchy (ftvprog)
--  fy          the FY to use in determining the description categories
--  sort        set to 'Y' to include the sorting number prefixes
-- Returns
--  Category string with or without a sorting index number
 return varchar2
is
ndesc varchar2(30);
nchem_desc12 varchar2(2);
nchem_desc13 varchar2(3);
nchem_code31 varchar2(1);
nchem_code32 varchar2(2);
nchem_code33 varchar2(3);
--
begin
  nchem_desc12 := substr(nchem_desc, 1, 2);
  nchem_desc13 := substr(nchem_desc, 1, 3);
  nchem_code31 := substr(nchem_code, 3, 1);
  nchem_code32 := substr(nchem_code, 3, 2);
  nchem_code33 := substr(nchem_code, 3, 3);
  -- new methodology based on SPBMGR
  if fy >= '2020' then
    if sort = 'Y' then
        -- add the sorting key 
        if   nchem_code = '1160GA'
          or  nchem_desc12 = 'HB' or  nchem_desc12 = 'SB' or  nchem_desc12 = 'SL'
          or  nchem_desc13 = 'Y2K'
          or  alloc_desc like '%SB%'  
                                  then ndesc := '90_Exclude';
        elsif nchem_code32 = '00' then ndesc := '13_Unallocated Authority';
        elsif nchem_code32 = '0X' then ndesc := '13_Unallocated Authority';
        elsif nchem_code32 = 'OX' then ndesc := '13_Unallocated Authority';
        elsif nchem_code32 = '10' then ndesc := '02_Instruction';
        elsif nchem_code32 = '20' then ndesc := '11_Research';
        elsif nchem_code32 = '30' then ndesc := '10_Public Service';
        elsif nchem_code32 = '40' then ndesc := '01_Academic Support';
        elsif nchem_code32 = '45' then ndesc := '04_Library Services';
        elsif nchem_code32 = '50' then ndesc := '06_Student Services';
        elsif nchem_code32 = '55' then ndesc := '03_Intercollegiate Athletics';
        elsif nchem_code32 = '60' then ndesc := '07_Institutional Support';
        elsif nchem_code32 = '61' then ndesc := '02_Instruction';
        elsif nchem_code32 = '63' then ndesc := '10_Public Service';
        elsif nchem_code32 = '64' then ndesc := '01_Academic Support';
        elsif nchem_code32 = '65' then ndesc := '07_Institutional Support';
        elsif nchem_code32 = '69' then ndesc := '08_Debt Service';
        elsif nchem_code32 = '70' then ndesc := '09_Physical Plant';
        elsif nchem_code32 = '80' then ndesc := '05_Scholarships';
        elsif nchem_code32 = '90' then ndesc := '12_Auxiliary Services';
        elsif nchem_code32 = '95' then ndesc := '08_Debt Service';
          else                         ndesc := '99_Needs Attention';
        end if;
    else
        -- no sorting key
        if    nchem_code = '1160GA'
          or  nchem_desc12 = 'HB' or  nchem_desc12 = 'SB' or  nchem_desc12 = 'SL'
          or  nchem_desc13 = 'Y2K'
          or  alloc_desc like '%SB%'  
                                  then ndesc := 'Exclude';
        elsif nchem_code32 = '00' then ndesc := 'Unallocated Authority';
        elsif nchem_code32 = '0X' then ndesc := 'Unallocated Authority';
        elsif nchem_code32 = 'OX' then ndesc := 'Unallocated Authority';
        elsif nchem_code32 = '10' then ndesc := 'Instruction';
        elsif nchem_code32 = '20' then ndesc := 'Research';
        elsif nchem_code32 = '30' then ndesc := 'Public Service';
        elsif nchem_code32 = '40' then ndesc := 'Academic Support';
        elsif nchem_code32 = '45' then ndesc := 'Library Services';
        elsif nchem_code32 = '50' then ndesc := 'Student Services';
        elsif nchem_code32 = '55' then ndesc := 'Intercollegiate Athletics';
        elsif nchem_code32 = '60' then ndesc := 'Institutional Support';
        elsif nchem_code32 = '61' then ndesc := 'Instruction';
        elsif nchem_code32 = '63' then ndesc := 'Public Service';
        elsif nchem_code32 = '64' then ndesc := 'Academic Support';
        elsif nchem_code32 = '65' then ndesc := 'Institutional Support';
        elsif nchem_code32 = '69' then ndesc := 'Debt Service';
        elsif nchem_code32 = '70' then ndesc := 'Physical Plant';
        elsif nchem_code32 = '80' then ndesc := 'Scholarships';
        elsif nchem_code32 = '90' then ndesc := 'Auxiliary Services';
        elsif nchem_code32 = '95' then ndesc := 'Debt Service';
          else                         ndesc := 'Needs Attention';
        end if;
    end if;
  -- from 2003 to 2019 
  elsif fy >= '2003' then
    if sort = 'Y' then
        if       nchem_code33 in ('0XN', '0X0', 'OX0') then ndesc := '13_Unallocated Authorization';
          elsif  nchem_code33 in ('100', '610', '006') then ndesc := '02_Instruction';
          elsif  nchem_code33 in ('25R', '200')        then ndesc := '11_Research';
          elsif  nchem_code33 in ('630', '300')        then ndesc := '10_Public Service';
          elsif  nchem_code33 in ('000', '400', '640') then ndesc := '01_Academic Support';
          elsif  nchem_code33 = '450'                  then ndesc := '04_Library Services';
          elsif  nchem_code33 = '500'                  then ndesc := '06_Student Services';
          elsif  nchem_code33 = '550'                  then ndesc := '03_Intercollegiate Athletics';
          elsif  nchem_code33 in ('600', '650', '002', '005', '160', '260', '360', '460', '660')
                                                       then ndesc := '07_Institutional Support';
          elsif  nchem_code33 = '700'                  then ndesc := '09_Physical Plant';
          elsif  nchem_code33 = '800'                  then ndesc := '05_Scholarships';
          elsif  nchem_code33 = '900'                  then ndesc := '12_Auxiliary Services';
          elsif  nchem_code33 in ('950', '695')        then ndesc := '08_Debt Service';
          else                                              ndesc := '99_Needs Attention';
        end if;
    else
        if       nchem_code33 in ('0XN', '0X0', 'OX0') then ndesc := 'Unallocated Authorization';
          elsif  nchem_code33 in ('100', '610', '006') then ndesc := 'Instruction';
          elsif  nchem_code33 in ('25R', '200')        then ndesc := 'Research';
          elsif  nchem_code33 in ('630', '300')        then ndesc := 'Public Service';
          elsif  nchem_code33 in ('000', '400', '640') then ndesc := 'Academic Support';
          elsif  nchem_code33 = '450'                  then ndesc := 'Library Services';
          elsif  nchem_code33 = '500'                  then ndesc := 'Student Services';
          elsif  nchem_code33 = '550'                  then ndesc := 'Intercollegiate Athletics';
          elsif  nchem_code33 in ('600', '650', '002', '005', '160', '260', '360', '460', '660')
                                                       then ndesc := 'Institutional Support';
          elsif  nchem_code33 = '700'                  then ndesc := 'Physical Plant';
          elsif  nchem_code33 = '800'                  then ndesc := 'Scholarships';
          elsif  nchem_code33 = '900'                  then ndesc := 'Auxiliary Services';
          elsif  nchem_code33 in ('950', '695')        then ndesc := 'Debt Service';
          else                                              ndesc := 'Needs Attention';
        end if;
    end if;
  -- typically, 1996 to 2002 
  else
    if sort = 'Y' then
        if       nchem_code33 in ('100', '610', '006') then ndesc := '02_Instruction';
          elsif  nchem_code33 in ('25R', '200')        then ndesc := '11_Research';
          elsif  nchem_code33 in ('630', '300')        then ndesc := '10_Public Service';
          elsif  nchem_code33 in ('000', '400', '640') then ndesc := '01_Academic Support';
          elsif  nchem_code33 = '450'                  then ndesc := '04_Library Services';
          elsif  nchem_code33 = '500'                  then ndesc := '06_Student Services';
          elsif  nchem_code33 = '550'                  then ndesc := '03_Intercollegiate Athletics';
          elsif  nchem_code33 in ('600', '650', '002', '005', '160', '260', '360', '460', '660')
                                                       then ndesc := '07_Institutional Support';
          elsif  nchem_code33 = '700'                  then ndesc := '09_Physical Plant';
          elsif  nchem_code33 = '800'                  then ndesc := '05_Scholarships';
          elsif  nchem_code33 = '900'                  then ndesc := '12_Auxiliary Services';
          elsif  nchem_code33 in ('950', '695')        then ndesc := '08_Debt Service';
          elsif  nchem_code33 in ('0XN', '0X0', 'OX0') then ndesc := '13_Unallocated Authorization';
          else                                              ndesc := '99_Needs Attention';
        end if;
    else 
        if       nchem_code33 in ('100', '610', '006') then ndesc := 'Instruction';
          elsif  nchem_code33 in ('25R', '200')        then ndesc := 'Research';
          elsif  nchem_code33 in ('630', '300')        then ndesc := 'Public Service';
          elsif  nchem_code33 in ('000', '400', '640') then ndesc := 'Academic Support';
          elsif  nchem_code33 = '450'                  then ndesc := 'Library Services';
          elsif  nchem_code33 = '500'                  then ndesc := 'Student Services';
          elsif  nchem_code33 = '550'                  then ndesc := 'Intercollegiate Athletics';
          elsif  nchem_code33 in ('600', '650', '002', '005', '160', '260', '360', '460', '660')
                                                       then ndesc := 'Institutional Support';
          elsif  nchem_code33 = '700'                  then ndesc := 'Physical Plant';
          elsif  nchem_code33 = '800'                  then ndesc := 'Scholarships';
          elsif  nchem_code33 = '900'                  then ndesc := 'Auxiliary Services';
          elsif  nchem_code33 in ('950', '695')        then ndesc := 'Debt Service';
          elsif  nchem_code33 in ('0XN', '0X0', 'OX0') then ndesc := 'Unallocated Authorization';
          else                                              ndesc := 'Needs Attention';
        end if;
    end if;
  end if;
  return ndesc;
end;