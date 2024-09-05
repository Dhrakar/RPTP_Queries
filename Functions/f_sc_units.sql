-- ========================================================================
-- f_sc_units()
--
--  This function is used to determine which UAF Staff Council election 
-- unit a person is a member of.  It relies on the home dLevel from the
-- employee's PAYROLL.PEBEMPL record.  All of the listed org codes are at
-- level 3 in the FTVORGN hierarchy.
--
-- Params
--   org  An orgn_code from FTVORGN that is compared to level3 in the 
--        REPORTS.FTVORGN_LEVELS view
-- ========================================================================
create or replace function f_sc_units(org VARCHAR2)
  return INTEGER
is begin
  -- Rural Campus Services
  IF org IN (
    '4UABB', -- Bristol Bay Campus
    '4UACC', -- Chukchi Campus
    '4UATV', -- Community and Technical COllege
    '4UIAC', -- Interior Alaska Campus
    '4UAKU', -- Kuskokwim Campus
    '4UANW', -- Northwest Campus
    '4UARC'  -- Rural College
  ) THEN RETURN 1;
  -- 
  -- Geophysical Institute Services
  ELSIF org IN (
    '665GI' -- Geophysical Institute
  ) THEN RETURN 2;
  --
  -- Arctic Institute Services
  ELSIF org IN (
    '6ASGMP', -- Alaska Sea Grant and MAP
    '62CFOS', -- College of Fisheries and Ocean Science
    '655IAB'  -- Institute of Arctic Biology
  ) THEN RETURN 3;
  --
  -- Research Services
  ELSIF org IN (
    '63ACEP', -- Alaska Center for Energy and Power
    'IARC',   -- International Arctic Research Center
    '6MUSM',  -- UA Museum of the North
    '60LIBR', -- Rasmuson Library (UAF)
    '6RESCH', -- Vice Chancellor for Research Office
    '6DPP'    -- VCR Development Programs and Projects
  ) THEN RETURN 4;
  --
  -- Academic Services
  ELSIF org IN (
    '6CEM',   -- College of Engineering and Mines
    '6COE',   -- School of Education
    '61CLA',  -- College of Liberal Arts
    '650CNS', -- College of Natural Science and Mathematics
    '675SOM', -- School of Management
    '6SNRE'   -- UAF Institute of Agriculture Natural Resources and Extension
  ) THEN RETURN 5;
  --
  -- Student Services
  ELSIF org IN (
    '6ELDE', -- eCampus
    '41ATH', -- Intercollegiate Athletics
    '4VCSS', -- Student Services
    '6SMRSS' -- Summer Sessions
  ) THEN RETURN 6;
  --
  -- Administrative Services
  ELSIF org IN (
    '4CHAN',  -- Chancellors Office
    '40DEV',  -- Development and Alumni Relations
    '5FINSV', -- Financial Services
    '6KUAC',  -- KUAC
    '6PROV',  -- Provost Office
    '40UR',   -- University Relations
    '5VCASO', -- Vice Chancellor for Administrative Services Office
    '4VCUSA', -- Vice Chancellor for Student Affairs Office
    '4UAFIT', -- Nanook Technology Services
    '4ADV'    -- University Advancement
  ) THEN RETURN 7;
  --
  -- Facilities and Safety Services
  ELSIF org IN (
    '5AVCFS', -- Facilities Services
    '5SAFE',  -- Safety Services
    '5VCASB'  -- UAF VCAS Procurement and Contract Svc
  ) THEN RETURN 8;
  --
  --
  -- Unknown Orgn code
  ELSE RETURN 99;
  END IF;
  
  END;
  /
