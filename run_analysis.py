"""Load the IBM HR CSV into SQLite, run every query in sql/queries.sql,
save results to output/*.csv and draw simple charts."""
import os
import re
import sqlite3
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# 1. Load CSV into a SQLite database
os.makedirs("output", exist_ok=True)  # create output/ if missing
df = pd.read_csv("data/hr_attrition.csv", encoding="utf-8-sig")
con = sqlite3.connect("output/hr.db")
df.to_sql("employees", con, if_exists="replace", index=False)

# 2. Run each named query
sql_text = open("sql/queries.sql", encoding="utf-8").read()
blocks = re.split(r"^-- name: (\w+)\s*$", sql_text, flags=re.M)[1:]
results = {}
for name, query in zip(blocks[0::2], blocks[1::2]):
    results[name] = pd.read_sql_query(query, con)
    results[name].to_csv(f"output/{name}.csv", index=False)
    print(f"\n=== {name} ===")
    print(results[name].to_string(index=False))

# 3. Charts
def bar(name, x, title, rotate=0):
    d = results[name]
    ax = d.plot.bar(x=x, y="attrition_pct", legend=False, color="#c0392b", figsize=(8, 4))
    ax.axhline(results["overall_attrition"].attrition_pct[0], ls="--", color="gray", label="company avg")
    ax.set_title(title); ax.set_ylabel("Attrition %"); ax.set_xlabel("")
    plt.xticks(rotation=rotate, ha="right" if rotate else "center")
    for p in ax.patches:
        ax.annotate(f"{p.get_height():.1f}", (p.get_x() + p.get_width() / 2, p.get_height()),
                    ha="center", va="bottom", fontsize=8)
    plt.tight_layout(); plt.savefig(f"output/{name}.png", dpi=120); plt.close()

bar("attrition_by_department", "Department", "Attrition % by Department")
bar("attrition_by_job_role", "JobRole", "Attrition % by Job Role", 40)
bar("attrition_by_overtime", "OverTime", "Attrition % by Overtime")
bar("attrition_by_tenure", "tenure_band", "Attrition % by Tenure")
bar("attrition_by_salary_band", "salary_band", "Attrition % by Salary Quartile", 20)
bar("highest_risk_profile", "risk_score", "Attrition % by Risk Score (0-5 flags)")
print("\nDone. Results and charts are in the output/ folder.")
