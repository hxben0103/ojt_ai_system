# scripts/generate_realistic_data.py
#
# Generates a realistic synthetic OJT training dataset where ALL features
# are populated with correlated, realistic values.
#
# Key design decisions:
# - Student archetypes (Strong / Average / At-Risk) drive correlated features
# - Required hours starts at 200 and varies per student (200-600)
# - Competency hours are distributed across 11 categories realistically
# - Target (risk_level) is derived from final weighted grade (same formula as live)
# - All features match the names in FEATURE_COLUMNS / PREDICTIVE_FEATURE_COLUMNS

import pandas as pd
import numpy as np
import os
import sys

# Seed for reproducibility
np.random.seed(42)

# =========================================================
# Constants
# =========================================================
NUM_STUDENTS = 1000

# Official OJT Grading Weights
WPR_WEIGHT = 0.20
NR_WEIGHT  = 0.20
CE_WEIGHT  = 0.20
SE_WEIGHT  = 0.40

# 11 Official OJT Competencies
COMPETENCY_COLUMNS = [
    "hours_software_development",
    "hours_machine_learning_engineering",
    "hours_it_related_research",
    "hours_ux_ui_design",
    "hours_information_security_analysis",
    "hours_networking",
    "hours_technical_support",
    "hours_data_analysis",
    "hours_customer_service",
    "hours_data_entry_management",
    "hours_office_work",
]

def classify_risk(grade: float) -> str:
    """Same formula as processdata.py"""
    if grade < 75:
        return "HIGH"
    elif grade < 85:
        return "MEDIUM"
    else:
        return "LOW"


def clamp(val, lo=0.0, hi=100.0):
    return max(lo, min(hi, val))


def generate_student(student_id: int, archetype: str) -> dict:
    """
    Generate a single student record with correlated features.

    Archetype determines the baseline quality of all metrics:
      - "strong"  : 85-100 percentile performance
      - "average" : 55-85  percentile performance
      - "at_risk" : 20-55  percentile performance
    """
    record = {"Student": f"Student_{student_id}"}

    # --- Base quality factor (0-1 continuous, drives all correlations) ---
    if archetype == "strong":
        quality = np.random.uniform(0.75, 1.0)
    elif archetype == "average":
        quality = np.random.uniform(0.45, 0.75)
    else:  # at_risk
        quality = np.random.uniform(0.10, 0.50)

    # Add per-student noise so features aren't perfectly correlated
    def q_noise(base_quality, noise_std=0.08):
        return clamp(base_quality + np.random.normal(0, noise_std), 0.0, 1.0)

    # --- Required Hours (200 - 600, varies by program) ---
    required_hours = np.random.choice([200, 240, 300, 400, 486, 600])
    record["required_hours"] = required_hours

    # --- OJT Duration (weekdays) ---
    # Approximate: required_hours / 8 hours per day, with some variation
    total_ojt_days = max(25, int(required_hours / 8 * np.random.uniform(0.9, 1.2)))

    # --- Attendance ---
    att_q = q_noise(quality, 0.10)
    # Days present as fraction of total OJT days
    attendance_fraction = clamp(att_q * np.random.uniform(0.85, 1.05), 0.0, 1.0)
    days_present = max(0, int(total_ojt_days * attendance_fraction))
    attendance_rate = clamp((days_present / total_ojt_days) * 100 if total_ojt_days > 0 else 0, 0, 100)

    # Hours completed = days_present * average hours per day (6-8.5)
    avg_hours_per_day = np.random.uniform(5.5, 8.5) * q_noise(quality, 0.05)
    total_hours_completed = round(days_present * avg_hours_per_day, 1)
    # Can't exceed a reasonable max
    total_hours_completed = min(total_hours_completed, required_hours * 1.15)

    hours_completed_ratio = clamp(
        total_hours_completed / required_hours if required_hours > 0 else 0, 0, 1.2
    )

    record["total_hours_completed"] = round(total_hours_completed, 1)
    record["attendance_rate"] = round(attendance_rate, 1)
    record["hours_completed_ratio"] = round(hours_completed_ratio, 3)

    # Late and absent counts
    late_q = 1.0 - q_noise(quality, 0.12)  # Inverse: bad students are late more
    late_count = max(0, int(days_present * late_q * np.random.uniform(0.0, 0.35)))
    absent_count = max(0, total_ojt_days - days_present)

    record["late_count"] = late_count
    record["absent_count"] = absent_count

    # --- Tasks & Competencies ---
    task_q = q_noise(quality, 0.12)

    # Total tasks logged (0-80 range)
    if task_q > 0.7:
        total_tasks = int(np.random.uniform(25, 80))
    elif task_q > 0.4:
        total_tasks = int(np.random.uniform(10, 35))
    else:
        total_tasks = int(np.random.uniform(0, 15))

    # Total task hours (correlated with tasks)
    avg_hours_per_task = np.random.uniform(1.5, 5.0)
    total_task_hours = round(total_tasks * avg_hours_per_task, 1)

    # Number of distinct competencies (1-11)
    if task_q > 0.7:
        num_competencies = int(np.random.uniform(5, 11))
    elif task_q > 0.4:
        num_competencies = int(np.random.uniform(2, 7))
    else:
        num_competencies = int(np.random.uniform(0, 4))
    num_competencies = max(0, min(11, num_competencies))

    record["total_tasks_logged"] = total_tasks
    record["total_task_hours"] = total_task_hours
    record["number_of_distinct_competencies"] = num_competencies

    # --- Distribute task hours across competencies ---
    for comp in COMPETENCY_COLUMNS:
        record[comp] = 0.0

    if num_competencies > 0 and total_task_hours > 0:
        # Pick which competencies this student works on
        active_competencies = np.random.choice(
            COMPETENCY_COLUMNS, size=num_competencies, replace=False
        )
        # Distribute hours with Dirichlet distribution (realistic uneven split)
        weights = np.random.dirichlet(np.ones(num_competencies) * 1.5)
        for comp, w in zip(active_competencies, weights):
            record[comp] = round(total_task_hours * w, 1)

    # --- Chatbot Engagement ---
    chat_q = q_noise(quality, 0.15)
    total_chatbot_queries = max(0, int(np.random.exponential(10) * chat_q + np.random.uniform(0, 5)))
    queries_last_30 = min(total_chatbot_queries, max(0, int(total_chatbot_queries * np.random.uniform(0.2, 0.7))))

    record["total_chatbot_queries"] = total_chatbot_queries
    record["chatbot_queries_last_30_days"] = queries_last_30

    # =========================================================
    # GRADING COMPONENTS (used to derive target, NOT as features)
    # =========================================================

    # Grade base correlates with quality but targets specific ranges per archetype
    # Strong students: grades in 82-100 range → mostly LOW risk (grade >= 85)
    # Average students: grades in 70-88 range → mostly MEDIUM risk (75 <= grade < 85)
    # At-risk students: grades in 50-76 range → mostly HIGH risk (grade < 75)
    
    if archetype == "strong":
        grade_base = np.random.uniform(82, 98)
    elif archetype == "average":
        grade_base = np.random.uniform(70, 88)
    else:  # at_risk
        grade_base = np.random.uniform(50, 76)

    # WPR: Weekly Progress Report (20%) — correlated with attendance + tasks
    wpr_noise = np.random.normal(0, 4)
    wpr_score = clamp(grade_base + wpr_noise + (attendance_rate - 60) * 0.1, 50, 100)

    # NR: Narrative Report (20%) — correlated with quality
    nr_score = clamp(grade_base + np.random.normal(0, 5), 50, 100)

    # CE: Coordinator Evaluation (20%) — correlated with overall quality
    ce_score = clamp(grade_base + np.random.normal(0, 5), 50, 100)

    # SE: Supervisor Evaluation (40%) — most important, correlated with tasks + attendance
    se_score = clamp(grade_base + np.random.normal(0, 4), 50, 100)

    record["weekly_progress_grade"] = round(wpr_score, 1)
    record["narrative_report_grade"] = round(nr_score, 1)
    record["coordinator_eval_grade"] = round(ce_score, 1)
    record["supervisor_eval_grade"] = round(se_score, 1)

    # Has flags (these students have grading data)
    record["has_weekly_progress_grade"] = 1
    record["has_narrative_report_grade"] = 1
    record["has_coordinator_eval_grade"] = 1
    # SE may be missing for some early-stage students (simulating active OJT)
    if hours_completed_ratio < 0.25 and np.random.random() < 0.3:
        record["supervisor_eval_grade"] = 0.0
        record["has_supervisor_eval_grade"] = 0
    else:
        record["has_supervisor_eval_grade"] = 1

    # =========================================================
    # COMPUTE TARGET: final_ojt_grade → risk_level
    # When SE is missing (0), redistribute weights among available
    # components — same logic as the live forecasting system.
    # =========================================================
    wpr_val = record["weekly_progress_grade"]
    nr_val  = record["narrative_report_grade"]
    ce_val  = record["coordinator_eval_grade"]
    se_val  = record["supervisor_eval_grade"]

    if se_val > 0:
        # All components available: standard weights
        final_grade = WPR_WEIGHT * wpr_val + NR_WEIGHT * nr_val + CE_WEIGHT * ce_val + SE_WEIGHT * se_val
    else:
        # SE missing: redistribute 40% weight across WPR, NR, CE equally
        active_weight = WPR_WEIGHT + NR_WEIGHT + CE_WEIGHT  # 0.60
        raw = WPR_WEIGHT * wpr_val + NR_WEIGHT * nr_val + CE_WEIGHT * ce_val
        final_grade = raw / active_weight if active_weight > 0 else 0

    record["final_ojt_grade"] = round(final_grade, 2)
    record["risk_level"] = classify_risk(final_grade)

    return record


def generate_dataset(num_students: int = NUM_STUDENTS) -> pd.DataFrame:
    """
    Generate a full dataset with balanced risk class distribution.

    Distribution targets:
    - ~30% Strong (LOW risk)
    - ~40% Average (MEDIUM risk)  
    - ~30% At-Risk (HIGH risk)
    """
    records = []

    # Assign archetypes to ensure balanced classes
    archetypes = (
        ["strong"] * int(num_students * 0.30) +
        ["average"] * int(num_students * 0.40) +
        ["at_risk"] * int(num_students * 0.30)
    )
    # Fill any rounding gap
    while len(archetypes) < num_students:
        archetypes.append(np.random.choice(["strong", "average", "at_risk"]))

    np.random.shuffle(archetypes)

    for i, archetype in enumerate(archetypes, 1):
        record = generate_student(i, archetype)
        records.append(record)

    df = pd.DataFrame(records)

    # Print summary stats
    print(f"\n{'='*60}")
    print(f"📊 GENERATED DATASET SUMMARY")
    print(f"{'='*60}")
    print(f"Total students: {len(df)}")
    print(f"\n🎯 Risk Level Distribution:")
    risk_counts = df["risk_level"].value_counts()
    for risk, count in risk_counts.items():
        print(f"   {risk}: {count} ({count/len(df)*100:.1f}%)")

    print(f"\n📈 Feature Ranges:")
    key_features = [
        "required_hours", "total_hours_completed", "attendance_rate",
        "hours_completed_ratio", "late_count", "absent_count",
        "total_tasks_logged", "total_task_hours",
        "number_of_distinct_competencies",
        "total_chatbot_queries"
    ]
    for feat in key_features:
        print(f"   {feat}: min={df[feat].min():.1f}, max={df[feat].max():.1f}, mean={df[feat].mean():.1f}")

    # Verify competency columns have non-zero values
    comp_nonzero = sum(1 for col in COMPETENCY_COLUMNS if df[col].sum() > 0)
    print(f"\n   Competency columns with data: {comp_nonzero}/{len(COMPETENCY_COLUMNS)}")

    print(f"\n📊 Grading Component Ranges:")
    for grade_col in ["weekly_progress_grade", "narrative_report_grade",
                       "coordinator_eval_grade", "supervisor_eval_grade"]:
        nonzero = df[df[grade_col] > 0][grade_col]
        print(f"   {grade_col}: min={nonzero.min():.1f}, max={nonzero.max():.1f}, mean={nonzero.mean():.1f}")

    print(f"\n   Final OJT Grade: min={df['final_ojt_grade'].min():.1f}, "
          f"max={df['final_ojt_grade'].max():.1f}, mean={df['final_ojt_grade'].mean():.1f}")

    return df


def main():
    print("🚀 Generating Realistic OJT Training Dataset...")

    df = generate_dataset()

    # Save to CSV
    output_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "data", "datasets")
    os.makedirs(output_dir, exist_ok=True)

    # Backup old dataset
    old_path = os.path.join(output_dir, "ojt_grading_data.csv")
    if os.path.exists(old_path):
        backup_path = os.path.join(output_dir, "ojt_grading_data_old.csv")
        import shutil
        shutil.copy2(old_path, backup_path)
        print(f"\n📦 Backed up old dataset to: {backup_path}")

    # Save new dataset
    output_path = os.path.join(output_dir, "ojt_grading_data.csv")
    df.to_csv(output_path, index=False)
    print(f"💾 New dataset saved to: {output_path}")
    print(f"   Shape: {df.shape}")
    print(f"   Columns: {list(df.columns)}")


if __name__ == "__main__":
    main()
