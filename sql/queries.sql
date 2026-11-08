-- Each query starts with "-- name: <name>" so run_analysis.py can run them one by one.
-- Table: employees (Attrition is 'Yes'/'No')

-- name: overall_attrition
SELECT COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM employees;

-- name: attrition_by_department
SELECT Department,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct,
       RANK() OVER (ORDER BY SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) DESC) AS rank_by_leavers
FROM employees
GROUP BY Department
ORDER BY attrition_pct DESC;

-- name: attrition_by_job_role
SELECT JobRole,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct,
       -- window function: how far is each role from the company average?
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*)
             - (SELECT 100.0 * SUM(Attrition = 'Yes') / COUNT(*) FROM employees), 1) AS vs_company_avg
FROM employees
GROUP BY JobRole
ORDER BY attrition_pct DESC;

-- name: attrition_by_overtime
SELECT OverTime,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM employees
GROUP BY OverTime
ORDER BY attrition_pct DESC;

-- name: attrition_by_tenure
SELECT CASE
         WHEN YearsAtCompany < 2  THEN '1. 0-1 yrs'
         WHEN YearsAtCompany < 5  THEN '2. 2-4 yrs'
         WHEN YearsAtCompany < 10 THEN '3. 5-9 yrs'
         ELSE                          '4. 10+ yrs'
       END AS tenure_band,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM employees
GROUP BY tenure_band
ORDER BY tenure_band;

-- name: attrition_by_salary_band
-- Salary bands = quartiles of MonthlyIncome, built with the NTILE window function
WITH banded AS (
  SELECT Attrition, MonthlyIncome,
         NTILE(4) OVER (ORDER BY MonthlyIncome) AS quartile
  FROM employees
)
SELECT CASE quartile WHEN 1 THEN 'Q1 (lowest pay)' WHEN 2 THEN 'Q2'
                     WHEN 3 THEN 'Q3' ELSE 'Q4 (highest pay)' END AS salary_band,
       MIN(MonthlyIncome) AS min_income,
       MAX(MonthlyIncome) AS max_income,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM banded
GROUP BY quartile
ORDER BY quartile;

-- name: overtime_and_low_pay
-- Combining both risk factors: overtime x low pay (bottom quartile)
WITH banded AS (
  SELECT Attrition, OverTime,
         NTILE(4) OVER (ORDER BY MonthlyIncome) AS quartile
  FROM employees
)
SELECT OverTime,
       CASE WHEN quartile = 1 THEN 'Low pay (Q1)' ELSE 'Other pay (Q2-Q4)' END AS pay_group,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM banded
GROUP BY OverTime, pay_group
ORDER BY attrition_pct DESC;

-- name: department_overtime_pay_rank
-- Window function: rank departments by attrition within each overtime group
SELECT OverTime, Department, headcount, attrition_pct,
       RANK() OVER (PARTITION BY OverTime ORDER BY attrition_pct DESC) AS rank_in_group
FROM (
  SELECT OverTime, Department, COUNT(*) AS headcount,
         ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
  FROM employees
  GROUP BY OverTime, Department
);

-- name: income_gap_leavers_vs_stayers
-- Average pay of leavers vs stayers within each job level (is pay lower for those who left?)
SELECT JobLevel,
       ROUND(AVG(CASE WHEN Attrition = 'Yes' THEN MonthlyIncome END)) AS avg_income_leavers,
       ROUND(AVG(CASE WHEN Attrition = 'No'  THEN MonthlyIncome END)) AS avg_income_stayers,
       COUNT(*) AS headcount
FROM employees
GROUP BY JobLevel
ORDER BY JobLevel;

-- name: highest_risk_profile
-- Simple risk score: count of risk flags per employee, then attrition by score
WITH flags AS (
  SELECT Attrition,
         (OverTime = 'Yes')
       + (MonthlyIncome < 3000)
       + (YearsAtCompany < 3)
       + (JobSatisfaction <= 2)
       + (BusinessTravel = 'Travel_Frequently') AS risk_score
  FROM employees
)
SELECT risk_score,
       COUNT(*) AS headcount,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM flags
GROUP BY risk_score
ORDER BY risk_score;
