"""
Chatbot handler wrapper for the JRMSU OJT Assistant.

This module wraps the RAG-based chatbot implementation located in jrmsu_ojt_chatbot/
and provides the chatbot_response function interface expected by server.py.

It now includes:
- Session-based conversation context management
- Structured error handling
- Fallback detection
- OJT topic restriction (only answers OJT/JRMSU-related queries)
- Role-aware response personalization (student, supervisor, coordinator, admin)
- Performance-based context injection from prediction/dashboard data
"""

import os
import sys
import logging
import traceback
from typing import Dict, Any, Optional

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Determine the current directory (where this file is located)
current_dir = os.path.dirname(os.path.abspath(__file__))

# Build the path to jrmsu_ojt_chatbot directory
jrmsu_dir = os.path.join(current_dir, "jrmsu_ojt_chatbot")

# Add jrmsu_ojt_chatbot to sys.path if it isn't already there
if jrmsu_dir not in sys.path:
    sys.path.insert(0, jrmsu_dir)

# Import the generate_response function from run_ai
from run_ai import generate_response

# Patch BASE_KNOWLEDGE_DIR to use absolute path
# This is needed because run_ai.py uses relative paths
import run_ai
run_ai.BASE_KNOWLEDGE_DIR = os.path.join(jrmsu_dir, "data", "jrmsu_knowledge")

# Import context manager
from chatbot_context import get_context_manager
from career_engine import generate_career_briefing


# ──────────────────────────────────────────────────────────────
# Shared constants
# ──────────────────────────────────────────────────────────────
# Risk sort order — used by coordinator & supervisor summaries and weekly digest
RISK_ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}

# Greeting patterns — used by both streaming (server.py) and non-streaming paths
GREETING_PATTERNS = [
    "hi", "hello", "hey", "good morning", "good afternoon",
    "good evening", "greetings", "hi there", "hello there",
]


# ──────────────────────────────────────────────────────────────
# OJT Topic Guard — WHITELIST ONLY (no blacklist)
# Only queries matching these keywords are processed.
# Everything else is blocked immediately — no resources wasted.
# ──────────────────────────────────────────────────────────────
OJT_TOPIC_KEYWORDS = [
    # ── OJT Core Terms ──
    "ojt", "internship", "practicum", "on the job", "on-the-job",
    "deployment", "host company", "industry partner",
    # ── Attendance / DTR ──
    "attendance", "dtr", "daily time record", "time in", "time out",
    "overtime", "check in", "check out", "tardy", "absent", "late",
    "present", "tardiness",
    # ── Requirements / Documentation ──
    "requirement", "journal", "narrative", "narrative report", "documentation",
    "submission", "deadline", "clearance", "weekly progress",
    # ── Grading / Performance ──
    "grade", "grading", "evaluation", "performance", "score",
    "prediction", "forecast", "insight", "analytics",
    # ── People / Roles (OJT-specific) ──
    "supervisor", "coordinator", "intern", "ojt student",
    "student", "students",  # standalone — users say "which student..."
    # ── Tasks / Competencies ──
    "competency", "competencies", "daily task", "task", "tasks",
    # ── University / Institution ──
    "jrmsu", "university", "ccs", "campus",
    "mission", "vision", "quality policy",
    # ── Policies ──
    "dress code", "attire", "uniform", "policy",
    "excuse", "waiver",
    # ── System / Dashboard ──
    "dashboard", "progress report", "program overview", "program health",
    # ── Company / Site ──
    "ojt site", "company name", "assigned student", "assigned to", "assigned",
    # ── Career ──
    "career", "employability", "skill gap",
    # ── Risk / Status (standalone) ──
    "risk", "status", "progress", "hours", "hour",
    "training", "report", "improvement", "recommendation", "data",
    # ── Student Self-Reference (personal data queries) ──
    "my ojt", "my attendance", "my grade", "my hours", "my score",
    "my performance", "my progress", "my status", "my risk", "my completion",
    "my data", "my record", "my report", "my training",
    # ── Common OJT Question Patterns ──
    "how am i doing", "am i on track", "how many hours", "how many days",
    "what is my", "what are my", "show me",
    "who are the student", "who is at risk", "tell me about the student",
    "student performance", "student attendance", "student risk",
    "students at risk", "students needing", "student status",
    "weekly summary", "weekly report",
    # ── Data Inquiry Patterns (OJT-context specific) ──
    "how is the student", "how are the student", "how is my",
    "summarize my", "summarize the", "overview of",
    "at risk", "high risk", "medium risk", "low risk", "higher risk",
    "needs attention", "needing attention",
    "ojt recommendation", "ojt improvement",
    "what can you do", "what can you help",
    # ── Metric Queries (OJT-scoped) ──
    "total hours", "average score", "attendance rate", "completion rate",
    "highest score", "lowest score", "risk level",
    # ── Natural variations users actually type ──
    "which student", "how is", "how are", "who has", "who have",
    "doing well", "not doing well", "struggling", "behind",
    "list of", "summary of", "details of",
]

# Fix #5: Pre-compile all keywords into a single regex for O(1) matching
# instead of looping through 100+ keywords with `in` substring checks.
import re as _re
_OJT_TOPIC_PATTERN = _re.compile(
    '|'.join(_re.escape(kw) for kw in sorted(OJT_TOPIC_KEYWORDS, key=len, reverse=True))
)



def _is_ojt_related(text: str, has_context: bool = False) -> bool:
    """
    WHITELIST-ONLY topic guard — single regex match.
    Returns True ONLY if the query contains at least one OJT keyword.
    Everything else is blocked immediately — no resources wasted,
    no data fetched, no Ollama call made.

    Uses a pre-compiled regex pattern for fast matching instead of
    looping through 100+ keywords.
    """
    text_lower = text.lower().strip()

    # Single regex pass — matches any OJT keyword
    if _OJT_TOPIC_PATTERN.search(text_lower):
        return True

    # No keyword match → block immediately
    logger.info(f"[TOPIC_GUARD] Query not OJT-related, blocking: {text_lower[:80]}")
    return False


# Friendly decline message — role-aware with targeted suggestions
OJT_DECLINE_MESSAGE = (
    "I'm your **JRMSU OJT Assistant** — I'm specialized for OJT-related topics only. "
    "I can't answer that question.\n\n"
    "Here's what I **can** help you with:\n"
    "- OJT progress, hours, and attendance\n"
    "- Student performance, risk levels, and grades\n"
    "- OJT requirements, deadlines, and documentation\n"
    "- JRMSU OJT policies and procedures\n\n"
    "Try asking something OJT-related!"
)


def _get_role_decline_message(role: str = "") -> str:
    """Return a role-specific decline message with targeted suggestions."""
    role_lower = role.lower().strip() if role else ""

    if role_lower == "student":
        return (
            "I'm your **JRMSU OJT Assistant** — I can only help with OJT-related topics. "
            "I can't answer that question.\n\n"
            "As a **student**, here's what I can help you with:\n"
            "- 📊 Your OJT progress, hours completed, and remaining hours\n"
            "- 📅 Your attendance record (present, absent, late)\n"
            "- 📈 Your AI performance score and risk level\n"
            "- 📝 OJT requirements, DTR, and documentation\n"
            "- 🎓 JRMSU OJT policies and grading system\n\n"
            "Try asking: *\"How am I doing in my OJT?\"* or *\"What are my hours?\"*"
        )

    elif role_lower in ("coordinator", "ojt coordinator"):
        return (
            "I'm your **JRMSU OJT Assistant** — I can only help with OJT-related topics. "
            "I can't answer that question.\n\n"
            "As a **coordinator**, here's what I can help you with:\n"
            "- 📊 Program overview — total students, risk breakdown, health status\n"
            "- ⚠️ Students at risk — who needs attention and why\n"
            "- 📈 Attendance trends and completion rates across all students\n"
            "- 🏢 Students by company/site assignment\n"
            "- 📋 Weekly summary and program analytics\n\n"
            "Try asking: *\"Show me students at risk\"* or *\"How is the program doing?\"*"
        )

    elif role_lower in ("supervisor", "industry supervisor"):
        return (
            "I'm your **JRMSU OJT Assistant** — I can only help with OJT-related topics. "
            "I can't answer that question.\n\n"
            "As a **supervisor**, here's what I can help you with:\n"
            "- 👥 Your assigned students' performance and status\n"
            "- ⚠️ Students needing attention — high risk or low attendance\n"
            "- 📝 Evaluation guidelines and grading rubric\n"
            "- 📊 Student scores, hours, and task completion\n"
            "- 📋 Recommendations for student improvement\n\n"
            "Try asking: *\"How are my students doing?\"* or *\"Who needs evaluation?\"*"
        )

    elif role_lower == "admin":
        return (
            "I'm your **JRMSU OJT Assistant** — I can only help with OJT-related topics. "
            "I can't answer that question.\n\n"
            "As an **admin**, here's what I can help you with:\n"
            "- 🏛️ System-wide OJT metrics and user statistics\n"
            "- 📊 Active users, pending approvals, and program status\n"
            "- 📋 JRMSU OJT policies and institutional guidelines\n"
            "- 🔧 System health and operational insights\n\n"
            "Try asking: *\"Show me system overview\"* or *\"What are the OJT policies?\"*"
        )

    # Fallback — no role detected
    return OJT_DECLINE_MESSAGE

# Explicit no-data response when student_data is absent
NO_DATA_MESSAGE = "No available data found in the system."

# Role whitelist for escalation guard
VALID_ROLES = {
    "student",
    "supervisor",
    "industry supervisor",
    "coordinator",
    "ojt coordinator",
    "admin",
}


def _validate_role(role: str) -> str:
    """
    Validate the role against the known whitelist.
    Returns the sanitised role string, or 'student' (most restrictive) if invalid.
    This prevents role escalation via a crafted student_data payload.
    """
    sanitised = (role or "").lower().strip()
    if sanitised not in VALID_ROLES:
        logger.warning(
            f"[ROLE_GUARD] Unknown or missing role '{sanitised}' — defaulting to 'student'"
        )
        return "student"
    return sanitised


def _is_greeting(text: str) -> bool:
    """Check if the message is a simple greeting."""
    text_lower = text.lower().strip()
    return text_lower in GREETING_PATTERNS or any(text_lower.startswith(g) for g in GREETING_PATTERNS)


# NOTE: _detect_intent was removed — it was dead code (result only logged, never branched on).
# If intent-specific routing is needed in the future, reintroduce with actual branching logic.


# ──────────────────────────────────────────────────────────────
# Role-Aware System Instructions
# ──────────────────────────────────────────────────────────────
def _build_role_system_instruction(role: str, student_data: Optional[Dict] = None) -> str:
    """
    Build a role-specific system instruction that tells the LLM
    how to frame its answers based on who is asking.
    """
    role = (role or "").lower().strip()

    if role == "student":
        ojt_status = "active"
        can_act = True
        if student_data:
            can_act = student_data.get("can_perform_ojt_actions", True)
            ojt_record = student_data.get("ojt_record", {})
            if ojt_record:
                ojt_status = (ojt_record.get("status", "active") or "active").lower()

        status_note = ""
        if not can_act:
            blocking = student_data.get("blocking_reason", "OJT setup incomplete") if student_data else ""
            status_note = (
                f" This student's OJT setup is currently incomplete ({blocking}). "
                "Guide them on what steps they need to complete before they can start tracking attendance and tasks."
            )
        elif ojt_status == "completed":
            status_note = (
                " This student has completed their OJT. Focus on clearance procedures, "
                "final documentation, and grading when answering their questions."
            )

        return (
            f"You are the JRMSU OJT Assistant speaking to a **Student**.{status_note} "
            "YOUR ROLE: You are their personal OJT mentor and academic advisor. "
            "TONE: Supportive, encouraging, and motivational. Speak as a mentor guiding them. "
            "DATA ACCESS: You have access to THIS student's personal OJT data including hours completed, "
            "attendance record, daily task count, AI performance score, risk level, and trend direction. "
            "WHAT TO DO: "
            "- When they ask about their progress, cite their exact hours, attendance, and score. "
            "- When they ask about grades, explain how their performance score and attendance affect their final grade. "
            "- When they ask about requirements, reference JRMSU OJT policies from the knowledge base. "
            "- When their risk is HIGH or MEDIUM, proactively suggest improvement steps. "
            "- Celebrate their achievements if their score is high or attendance is perfect. "
            "- If they ask about other students or system-wide data, say you can only show their own data. "
            "SCOPE: Only answer OJT, JRMSU, and academic questions. Politely decline anything else."
        )

    elif role == "supervisor" or role == "industry supervisor":
        return (
            "You are the JRMSU OJT Assistant speaking to an **Industry Supervisor**. "
            "YOUR ROLE: You are their professional OJT management assistant. "
            "TONE: Professional, collegial, and action-oriented. Speak as a colleague helping them manage trainees. "
            "DATA ACCESS: You have data on the students assigned to this supervisor, including each student's "
            "name, risk level, AI score, hours completed, attendance rate, and absences. "
            "WHAT TO DO: "
            "- When they ask about their students, list each student with their risk level and key metrics. "
            "- When they ask about high-risk students, identify those with HIGH or MEDIUM risk and explain why. "
            "- When they ask about evaluations, explain the JRMSU evaluation process and grading rubric. "
            "- Provide actionable recommendations: who needs a check-in, who is on track. "
            "- When a student has many absences or low score, suggest specific interventions. "
            "- If they ask about the OJT program policies, reference the JRMSU knowledge base. "
            "- If they ask about other supervisors' students, say you can only show their assigned students. "
            "SCOPE: Only answer OJT, JRMSU, and academic questions. Politely decline anything else."
        )

    elif role == "coordinator" or role == "ojt coordinator":
        return (
            "You are the JRMSU OJT Assistant speaking to an **OJT Coordinator**. "
            "YOUR ROLE: You are their program analytics and oversight assistant. "
            "TONE: Professional, data-driven, and strategic. Speak as an institutional advisor. "
            "DATA ACCESS: You have program-wide data including total student count, risk distribution "
            "(HIGH/MEDIUM/LOW counts), active vs completed OJT, average attendance rate, average completion "
            "ratio, average forecasted grade, per-student performance details including their assigned "
            "company/site, supervisor name, and detailed attendance (days present, absent, late). "
            "WHAT TO DO: "
            "- When asked about students at a specific COMPANY or SITE, look at the 'Site:' field in Student Details "
            "and list only students assigned to that company. Include their scores, attendance, and risk. "
            "- When asked about a SUPERVISOR's students, look at the 'Supervisor:' field and list their assigned students. "
            "- When asked about ATTENDANCE, provide days present, days absent, late count, and attendance rate for each student. "
            "- When asked about high-risk students, list students with HIGH risk first, then MEDIUM, with their details. "
            "- When asked for a PROGRAM OVERVIEW, give total counts, risk breakdown, averages, and program health. "
            "- When asked about a SPECIFIC STUDENT by name, find them in the data and give all their details. "
            "- When asked to COMPARE students or sites, create a comparison using their scores, hours, and attendance. "
            "- Provide strategic RECOMMENDATIONS based on patterns: who needs intervention, which sites have issues. "
            "- When asked about GRADES, reference each student's forecasted grade and what factors affect it. "
            "- When asked about policies or procedures, reference the JRMSU OJT knowledge base. "
            "IMPORTANT: Always use the actual student data from the prompt. Never make up names or numbers. "
            "SCOPE: Only answer OJT, JRMSU, and academic questions. Politely decline anything else."
        )

    elif role == "admin":
        return (
            "You are the JRMSU OJT Assistant speaking to a **System Administrator**. "
            "YOUR ROLE: You are their platform management and system oversight assistant. "
            "TONE: Formal, technical, and concise. Speak as a system analyst. "
            "DATA ACCESS: You have system-wide data including total users, active users, pending approvals, "
            "and coordinator count. "
            "WHAT TO DO: "
            "- When they ask about system status, give user counts and approval queue sizes. "
            "- When they ask about user management, explain the JRMSU role hierarchy and approval flow. "
            "- When they ask about platform operations, reference system metrics. "
            "- Help with administrative oversight questions about the OJT platform. "
            "SCOPE: Only answer OJT, JRMSU, platform administration, and academic questions. Politely decline anything else."
        )

    # Default / Unknown role
    return (
        "You are the JRMSU OJT Assistant. "
        "You must ONLY answer questions related to OJT, JRMSU, and academic matters. "
        "If the question is outside this scope, politely decline."
    )


# ──────────────────────────────────────────────────────────────
# Dashboard Data Summaries (role-specific)
# ──────────────────────────────────────────────────────────────
def _generate_student_summary(data: Dict) -> str:
    """Generate a forceful, directive summary for a student's dashboard data.
    
    The summary embeds explicit instructions that force the LLM to cite
    the actual numbers rather than giving generic responses.
    """
    hours = data.get('hours', {})
    completed = hours.get('completed', 0)
    required = hours.get('required', 300)
    remaining = max(0, required - completed)
    progress_pct = round((completed / required * 100), 1) if required > 0 else 0

    attendance = data.get('attendance', {})
    present = attendance.get('days_present', 0)
    absent = attendance.get('absent_days', 0)
    late = attendance.get('late_count', 0)

    tasks = data.get('daily_tasks', {})
    done = tasks.get('completed_tasks', 0)
    pending = tasks.get('pending_tasks', 0)

    ai = data.get('ai_insight', {})
    score = ai.get('score', 0)
    risk = ai.get('risk_level', 'Unknown')
    trend = ai.get('trend', {})
    trend_dir = trend.get('direction', 'stable') if isinstance(trend, dict) else 'stable'

    # OJT record status
    ojt_status = "Active"
    can_act = data.get('can_perform_ojt_actions', True)
    ojt_record = data.get('ojt_record', {})
    if ojt_record:
        ojt_status = ojt_record.get('status', 'Active')

    # Feature 5: Minimum data threshold — don't show unreliable risk if < 5 days
    total_days = present + absent
    if total_days < 5:
        risk = "INSUFFICIENT DATA"
        risk_note = f"Only {total_days} day(s) of data available. At least 5 OJT days needed for reliable risk assessment."
    else:
        risk_note = ""

    # Build a performance assessment phrase based on score
    if score >= 80:
        perf_assessment = "performing well"
    elif score >= 60:
        perf_assessment = "performing at a moderate level"
    elif score > 0:
        perf_assessment = "underperforming and needs improvement"
    else:
        perf_assessment = "not yet scored by the AI system"

    # Build attendance assessment
    if present > 0 and absent == 0 and late == 0:
        att_assessment = "excellent attendance with no absences or tardiness"
    elif late > 3:
        att_assessment = f"frequent tardiness ({late} late arrivals) which affects their score"
    elif absent > 3:
        att_assessment = f"concerning absences ({absent} days absent)"
    else:
        att_assessment = "acceptable attendance"

    # Feature 4: Risk explanation — build key factors
    risk_factors = []
    if absent > 5:
        risk_factors.append(f"High absences ({absent} days)")
    if late > 3:
        risk_factors.append(f"Frequent tardiness ({late} times late)")
    if progress_pct < 10 and completed < 20:
        risk_factors.append(f"Very low hours completion ({progress_pct}%)")
    if score > 0 and score < 50:
        risk_factors.append(f"Low AI performance score ({score}/100)")
    if done == 0:
        risk_factors.append("No completed tasks logged")

    summary = (
        f"\n[STUDENT PERFORMANCE DATA — YOU MUST USE THESE EXACT NUMBERS IN YOUR RESPONSE]\n"
        f"IMPORTANT: The following is this student's REAL data from the system. "
        f"You MUST mention these specific numbers when answering.\n\n"
        f"OJT Status: {ojt_status}\n"
        f"Hours: {completed} out of {required} hours completed ({progress_pct}% done), {remaining} hours remaining\n"
        f"Attendance: {present} days present, {absent} days absent, {late} late arrivals\n"
        f"Daily Tasks: {done} tasks completed, {pending} tasks pending approval\n"
        f"AI Performance Score: {score}/100\n"
        f"Risk Level: {risk}\n"
        f"Trend: {trend_dir}\n\n"
    )

    # Add risk explanation
    if risk_note:
        summary += f"DATA NOTICE: {risk_note}\n"
    elif risk_factors:
        summary += f"Risk Factors: {'; '.join(risk_factors)}\n"
    elif risk == 'LOW':
        summary += "Risk Factors: None — student is on track.\n"

    summary += f"ASSESSMENT: This student is {perf_assessment}. They have {att_assessment}.\n"

    if not can_act:
        blocking = data.get('blocking_reason', 'OJT setup incomplete')
        summary += f"OJT BLOCKED: {blocking}\n"

    return summary


def _generate_coordinator_summary(data: Dict) -> str:
    """Generate an explanatory summary for a coordinator's dashboard data.

    GAP 4 FIX — Adds auto-detected trend flags section identifying common issues
    (mass absences, high tardiness, low scores, low attendance rate) across all students.
    """
    total = data.get('total_students', 0)
    high_risk = data.get('high_risk_students', 0)
    medium_risk = data.get('medium_risk_students', 0)
    low_risk = data.get('low_risk_students', 0)
    active = data.get('active_ojt', 0)
    completed = data.get('completed_ojt', 0)
    avg_attendance = data.get('average_attendance', 0)
    avg_completion = data.get('average_completion', 0)
    avg_grade = data.get('average_forecast_grade', 'N/A')

    student_details = data.get('student_details', [])

    # Handle empty data gracefully — either no students assigned or loading failed
    if total == 0 and not student_details:
        logger.warning("[COORDINATOR_SUMMARY] No students found — data may not have loaded yet")
        return (
            "\n[COORDINATOR PROGRAM DATA]\n"
            "No students are currently assigned to this coordinator account. "
            "This may mean the dashboard data has not finished loading yet. "
            "Please return to the dashboard, wait for it to fully load, then reopen the chatbot.\n"
        )

    # Round floats for cleaner display
    avg_att_str = f"{avg_attendance:.1f}" if isinstance(avg_attendance, (int, float)) else str(avg_attendance)
    avg_comp_str = f"{avg_completion:.1f}" if isinstance(avg_completion, (int, float)) else str(avg_completion)
    avg_grade_str = f"{avg_grade:.1f}" if isinstance(avg_grade, (int, float)) else str(avg_grade)

    # Program health assessment
    if high_risk > total * 0.3:
        health = "CRITICAL — over 30% of students are at High Risk"
    elif medium_risk > total * 0.5:
        health = "NEEDS ATTENTION — over 50% of students are at Medium Risk"
    elif float(avg_att_str) < 50:
        health = "CONCERNING — average attendance is below 50%"
    else:
        health = "STABLE — most students are on track"

    summary = (
        f"\n[COORDINATOR PROGRAM DATA]\n"
        f"Program Overview:\n"
        f"  Total Students: {total} ({active} Active, {completed} Completed)\n"
        f"  Risk Breakdown: {high_risk} High Risk, {medium_risk} Medium Risk, {low_risk} Low Risk\n"
        f"  Average Attendance: {avg_att_str}%\n"
        f"  Average Completion: {avg_comp_str}%\n"
        f"  Average Forecasted Grade: {avg_grade_str}\n"
        f"  Program Health: {health}\n"
    )

    # GAP 4 — Auto-detect trends and common issues from student details
    if student_details:
        frequent_absent = [s.get('name', 'Unknown') for s in student_details if (s.get('days_absent') or 0) > 3]
        high_tardiness = [s.get('name', 'Unknown') for s in student_details if (s.get('late_count') or 0) > 5]
        low_score = [s.get('name', 'Unknown') for s in student_details if (s.get('score') or 0) < 60]
        low_attendance = [s.get('name', 'Unknown') for s in student_details if (s.get('attendance_rate') or 0) < 10]

        issues = []
        if frequent_absent:
            issues.append(f"{len(frequent_absent)} student(s) with more than 3 absences: {', '.join(frequent_absent[:5])}")
        if high_tardiness:
            issues.append(f"{len(high_tardiness)} student(s) with frequent tardiness: {', '.join(high_tardiness[:5])}")
        if low_score:
            issues.append(f"{len(low_score)} student(s) with low AI scores (below 60): {', '.join(low_score[:5])}")
        if low_attendance:
            issues.append(f"{len(low_attendance)} student(s) with very low attendance (below 10%): {', '.join(low_attendance[:5])}")

        if issues:
            summary += "\nKey Issues Detected:\n"
            for issue in issues:
                summary += f"  - {issue}\n"
        else:
            summary += "\nKey Issues: No critical issues detected.\n"

        # ── Company/Site Grouping (enables questions like "students at JRMSU") ──
        from collections import defaultdict
        company_groups = defaultdict(list)
        for s in student_details:
            company = (s.get('company') or 'Unassigned').strip()
            company_groups[company].append(s.get('name', 'Unknown'))

        summary += "\nAssignment Sites (Company/Organization):\n"
        for company, names in sorted(company_groups.items()):
            summary += f"  {company}: {len(names)} student(s) — {', '.join(names[:6])}\n"

        # ── Per-Student Details (sorted by risk, capped at 10) ──
        sorted_students = sorted(student_details, key=lambda s: RISK_ORDER.get(s.get('risk_level', 'LOW').upper(), 3))
        capped = sorted_students[:10]
        remaining = len(student_details) - len(capped)

        summary += "\nStudent Details:\n"
        for s in capped:
            name = s.get('name', 'Unknown')
            risk = (s.get('risk_level') or 'N/A').upper()
            score = s.get('score', 0)
            hrs_done = s.get('hours_completed', 0)
            hrs_req = s.get('hours_required', 300)
            att_rate = s.get('attendance_rate', 0)
            present = s.get('days_present', 0)
            absent = s.get('days_absent', 0)
            late = s.get('late_count', 0)
            grade = s.get('forecasted_grade')
            grade_str = f"{grade:.1f}" if grade else 'N/A'
            company = s.get('company', 'N/A')
            supervisor = s.get('supervisor', 'N/A')

            # Feature 5: Data threshold for per-student
            total_student_days = present + absent
            if total_student_days < 5:
                risk_tag = "[INSUFFICIENT DATA]"
            else:
                risk_tag = f"[{risk} RISK]"

            # Feature 4: Risk factors per student
            risk_factors = []
            if absent > 5:
                risk_factors.append(f"high absences ({absent})")
            if att_rate < 10:
                risk_factors.append("very low attendance")
            if score and score < 50:
                risk_factors.append(f"low score ({score}/100)")
            if late > 5:
                risk_factors.append(f"frequent tardiness ({late})")
            if hrs_done == 0:
                risk_factors.append("no hours logged")
            # Get key_factors from prediction if available
            pred_factors = s.get('key_factors', [])
            if pred_factors:
                risk_factors.extend(pred_factors[:2])  # Add top 2 AI-detected factors

            factors_text = f" Why: {', '.join(risk_factors)}." if risk_factors else ""

            summary += (
                f"  {risk_tag} {name} | Site: {company} | Supervisor: {supervisor}\n"
                f"    Score: {score}/100, Hours: {hrs_done}/{hrs_req}, "
                f"Attendance: {present} present / {absent} absent / {late} late ({att_rate}%), "
                f"Grade: {grade_str}{factors_text}\n"
            )

        if remaining > 0:
            summary += f"  ... and {remaining} more students not shown.\n"

        # ── Recommendations ──
        summary += "\nRecommended Actions:\n"
        if high_risk > 0:
            summary += f"  1. Immediately follow up with the {high_risk} High Risk student(s).\n"
        if frequent_absent:
            summary += f"  {'2' if high_risk > 0 else '1'}. Address attendance issues — {len(frequent_absent)} student(s) have excessive absences.\n"
        if float(avg_att_str) < 30:
            summary += f"  - Overall attendance is critically low at {avg_att_str}%. Consider a program-wide intervention.\n"
        if not high_risk and not frequent_absent:
            summary += "  - No urgent actions required. Continue regular monitoring.\n"

    return summary


def _generate_weekly_summary(data: Dict) -> str:
    """Feature 6: Generate a structured weekly digest for coordinators/supervisors.
    This runs WITHOUT Ollama — it's pure data analysis, returned instantly."""
    import datetime

    role = (data.get('role') or '').lower()
    today = datetime.datetime.now().strftime("%B %d, %Y")
    student_details = data.get('student_details', [])
    total = data.get('total_students', len(student_details))
    high_risk = data.get('high_risk_students', 0)
    medium_risk = data.get('medium_risk_students', 0)
    low_risk = data.get('low_risk_students', 0)

    report = f"# Weekly OJT Program Summary\n"
    report += f"**Generated:** {today}\n"
    report += f"**Total Students:** {total}\n\n"

    # ── Section 1: Risk Overview ──
    report += "## Risk Distribution\n"
    if high_risk > 0:
        report += f"- **{high_risk} HIGH RISK** students need immediate attention\n"
    report += f"- **{medium_risk} MEDIUM RISK** students need monitoring\n"
    report += f"- **{low_risk} LOW RISK** students are on track\n\n"

    if not student_details:
        report += "*No detailed student data available for analysis.*\n"
        return report

    # ── Section 2: Students Needing Attention ──
    sorted_students = sorted(student_details,
                             key=lambda s: RISK_ORDER.get((s.get('risk_level') or 'LOW').upper(), 3))

    at_risk = [s for s in sorted_students if (s.get('risk_level') or 'LOW').upper() in ('HIGH', 'MEDIUM')]
    if at_risk:
        report += "## Students Needing Attention\n"
        for s in at_risk[:8]:
            name = s.get('name', 'Unknown')
            risk = (s.get('risk_level') or 'N/A').upper()
            score = s.get('score', 0)
            absent = s.get('days_absent', 0)
            company = s.get('company', 'N/A')
            # Build reason
            reasons = []
            if absent > 5:
                reasons.append(f"{absent} absences")
            if score and score < 50:
                reasons.append(f"score {score}/100")
            if s.get('hours_completed', 0) == 0:
                reasons.append("no hours logged")
            reason_text = f" ({', '.join(reasons)})" if reasons else ""
            report += f"- **{name}** [{risk}] at {company}{reason_text}\n"
        report += "\n"

    # ── Section 3: Attendance Analysis ──
    total_present = sum(s.get('days_present', 0) for s in student_details)
    total_absent = sum(s.get('days_absent', 0) for s in student_details)
    avg_att = data.get('average_attendance', 0)

    report += "## Attendance Overview\n"
    report += f"- Program-wide average attendance: **{avg_att}%**\n"
    report += f"- Total present days across all students: **{total_present}**\n"
    report += f"- Total absent days across all students: **{total_absent}**\n"

    # Worst attendance
    worst_att = sorted(student_details, key=lambda s: s.get('days_absent', 0), reverse=True)[:3]
    if worst_att and worst_att[0].get('days_absent', 0) > 0:
        report += "- **Most absences:**\n"
        for s in worst_att:
            if s.get('days_absent', 0) > 0:
                report += f"  - {s.get('name', 'Unknown')}: {s.get('days_absent', 0)} absent days\n"
    report += "\n"

    # ── Section 4: Performance Rankings ──
    scored = [s for s in student_details if (s.get('score') or 0) > 0]
    if scored:
        top = sorted(scored, key=lambda s: s.get('score', 0), reverse=True)[:3]
        bottom = sorted(scored, key=lambda s: s.get('score', 0))[:3]

        report += "## Performance Rankings\n"
        report += "**Top Performers:**\n"
        for i, s in enumerate(top, 1):
            report += f"  {i}. {s.get('name', 'Unknown')} — Score: {s.get('score', 0)}/100\n"
        report += "\n**Needs Improvement:**\n"
        for i, s in enumerate(bottom, 1):
            report += f"  {i}. {s.get('name', 'Unknown')} — Score: {s.get('score', 0)}/100\n"
        report += "\n"

    # ── Section 5: Site Summary ──
    from collections import defaultdict
    company_stats = defaultdict(lambda: {'count': 0, 'total_score': 0, 'total_absent': 0})
    for s in student_details:
        c = (s.get('company') or 'Unassigned').strip()
        company_stats[c]['count'] += 1
        company_stats[c]['total_score'] += (s.get('score') or 0)
        company_stats[c]['total_absent'] += (s.get('days_absent') or 0)

    if len(company_stats) > 1:
        report += "## Site Performance\n"
        for company, stats in sorted(company_stats.items()):
            avg_score = stats['total_score'] / stats['count'] if stats['count'] > 0 else 0
            report += f"- **{company}**: {stats['count']} student(s), avg score {avg_score:.0f}/100, {stats['total_absent']} total absences\n"
        report += "\n"

    # ── Section 6: Recommendations ──
    report += "## Recommended Actions This Week\n"
    action_num = 1
    if high_risk > 0:
        report += f"{action_num}. Schedule individual meetings with the {high_risk} HIGH risk student(s)\n"
        action_num += 1
    if total_absent > total_present * 0.3:
        report += f"{action_num}. Address program-wide attendance — absences are {total_absent} vs {total_present} present days\n"
        action_num += 1
    worst_company = max(company_stats.items(), key=lambda x: x[1]['total_absent'], default=None)
    if worst_company and worst_company[1]['total_absent'] > 10:
        report += f"{action_num}. Follow up with site **{worst_company[0]}** — highest absence count ({worst_company[1]['total_absent']} days)\n"
        action_num += 1
    if action_num == 1:
        report += "- All students are performing well. Continue regular monitoring.\n"

    report += "\n*This summary is auto-generated from your current program data.*"
    return report


# _RISK_ORDER removed — now uses shared RISK_ORDER constant at top of file


def _supervisor_recommendation(student: Dict) -> str:
    """Return a one-line recommendation based on the student's risk level and score."""
    risk = (student.get('risk_level') or 'LOW').upper()
    score = student.get('score', 0) or 0
    absent = student.get('days_absent', 0) or 0
    late = student.get('late_count', 0) or 0

    if risk == 'HIGH':
        return "Immediate intervention recommended — schedule a check-in meeting."
    elif risk == 'MEDIUM':
        if absent > 3:
            return "Monitor closely — student has frequent absences this period."
        elif late > 5:
            return "Monitor closely — student has repeated tardiness issues."
        else:
            return "Monitor closely this week — performance is below target."
    else:  # LOW
        if score >= 80:
            return "On track — no action required."
        else:
            return "On track — encourage continued consistency."


def _generate_supervisor_summary(data: Dict) -> str:
    """Generate an explanatory summary for a supervisor's dashboard data.

    GAP 3 FIX — Students sorted HIGH→MEDIUM→LOW with per-student recommendations.
    Response format: Name / Status / Issues / Recommendation (matches system prompt spec).
    """
    total = data.get('total_assigned', 0)
    pending_eval = data.get('pending_evaluations', 0)
    high_risk = data.get('high_risk_students', 0)
    avg_score = data.get('average_forecast_score', 'N/A')

    student_details = data.get('student_details', [])

    summary = (
        f"\n[SUPERVISOR OVERSIGHT DATA]\n"
        f"Assigned Students: {total}\n"
        f"Pending Evaluations: {pending_eval}\n"
        f"Students Needing Attention (High Risk): {high_risk}\n"
        f"Average Forecast Score: {avg_score}\n"
    )

    if student_details:
        # Sort by risk: HIGH first, then MEDIUM, then LOW
        sorted_students = sorted(
            student_details,
            key=lambda s: RISK_ORDER.get((s.get('risk_level') or 'LOW').upper(), 2)
        )
        summary += "\nAssigned Student Details (sorted by risk):\n"
        for s in sorted_students:
            name = s.get('name', 'Unknown')
            risk = s.get('risk_level', 'N/A')
            status = s.get('status', 'Active')
            company = s.get('company', 'N/A')
            score = s.get('score', 'N/A')
            absent = s.get('days_absent', 0)
            late = s.get('late_count', 0)
            recommendation = _supervisor_recommendation(s)

            # Build issues list
            issues = []
            if (s.get('risk_level') or '').upper() == 'HIGH':
                issues.append("High risk flag")
            if absent > 3:
                issues.append(f"{absent} absences")
            if late > 5:
                issues.append(f"{late} late arrivals")
            if not issues:
                issues.append("None")

            summary += (
                f"- Student Name: {name}\n"
                f"  Status: {status} | Company: {company}\n"
                f"  AI Score: {score}/100 | Risk: {risk}\n"
                f"  Issues: {', '.join(issues)}\n"
                f"  Recommendation: {recommendation}\n"
            )

    return summary


def _generate_admin_summary(data: Dict) -> str:
    """Generate an explanatory summary for an admin's dashboard data."""
    summary = (
        f"\n[ADMIN SYSTEM DATA]\n"
        f"Total Users: {data.get('total_users', 0)}\n"
        f"Active Users: {data.get('active_users', 0)}\n"
        f"Pending Approvals: {data.get('pending_users', 0)}\n"
        f"Registered Coordinators: {data.get('coordinator_count', 0)}\n"
    )
    return summary


# ──────────────────────────────────────────────────────────────
# Main Chatbot Response Handler
# ──────────────────────────────────────────────────────────────
def chatbot_response(
    user_message: str,
    session_id: Optional[str] = None,
    student_data: Optional[Dict] = None
) -> Dict[str, Any]:
    """
    Enhanced chatbot response handler with conversation context support.
    
    This function handles the full chatbot pipeline including:
    - Session management and conversation history
    - OJT topic restriction (declines off-topic queries)
    - Role-aware response personalization
    - Performance-based context injection from dashboard/prediction data
    - RAG-based answer generation
    - Error handling and fallback responses
    - Structured response formatting
    
    Args:
        user_message: The user's input message
        session_id: Optional session identifier for conversation context.
                    If None, uses a default session or creates a temporary one.
        student_data: Optional dashboard data dict containing role, metrics,
                     and performance data for context injection.
    
    Returns:
        Dictionary with structured response:
        {
            "success": bool,
            "answer": str | None,
            "is_fallback": bool,
            "session_id": str,
            "used_context": List[str],
            "confidence_score": float,
            "error_type": str | None,
            "message": str | None
        }
        
        On error:
        {
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE" | "INVALID_INPUT" | ...,
            "message": "Human-readable error message",
            "answer": None,
            "session_id": session_id,
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }
    """
    # Basic input validation
    text = (user_message or "").strip()
    if not text:
        return {
            "success": False,
            "error_type": "INVALID_INPUT",
            "message": "Please type a message so I can help you.",
            "answer": None,
            "session_id": session_id or "default",
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }

    # Check for simple greetings — return friendly role-aware response without RAG
    if _is_greeting(text):
        logger.info(f"[CHATBOT_HANDLER] Detected greeting: {text}")
        role = (student_data or {}).get('role', '').lower()
        greeting = _get_role_greeting(role)
        return {
            "success": True,
            "answer": greeting,
            "is_fallback": False,
            "session_id": session_id or "default",
            "used_context": [],
            "confidence_score": 1.0,
            "error_type": None,
            "message": None
        }

    # GAP 1 FIX — Return canonical no-data message when student asks about
    # personal metrics but no student_data payload was provided
    PERSONAL_METRIC_KEYWORDS = [
        "my hours", "my attendance", "my score", "my performance", "my grade",
        "my progress", "my tasks", "my status", "my risk", "how am i doing",
        "how many hours", "how many days", "my ojt",
    ]
    if not student_data and any(kw in text.lower() for kw in PERSONAL_METRIC_KEYWORDS):
        logger.info(f"[CHATBOT_HANDLER] No student_data for personal metric query: {text[:80]}")
        return {
            "success": True,
            "answer": NO_DATA_MESSAGE,
            "is_fallback": False,
            "session_id": session_id or "default",
            "used_context": [],
            "confidence_score": 1.0,
            "error_type": None,
            "message": None
        }

    # ── OJT TOPIC GUARD ──
    has_context = bool(student_data)
    if not _is_ojt_related(text, has_context=has_context):
        _role = (student_data or {}).get('role', '') if student_data else ''
        logger.info(f"[CHATBOT_HANDLER] Declined off-topic query (role={_role}): {text[:80]}")
        return {
            "success": True,
            "answer": _get_role_decline_message(_role),
            "is_fallback": False,
            "session_id": session_id or "default",
            "used_context": [],
            "confidence_score": 1.0,
            "error_type": None,
            "message": None
        }

    # Get or create session context
    session_id = session_id or "default"
    context_manager = get_context_manager()

    try:
        context = context_manager.get_or_create_context(session_id)

        # Add user message to context
        context.add_user_message(text)

        # Get conversation history for context-aware responses
        conversation_history = context.get_recent_history(max_turns=5)

        logger.info(f"[CHATBOT_HANDLER] Processing message for session {session_id}")

        # ── Build role-aware context ──
        role = ""
        dashboard_context = ""
        role_instruction = ""

        if student_data:
            try:
                # GAP 2 FIX — Validate role against whitelist before using it
                raw_role = student_data.get('role', '')
                role = _validate_role(raw_role)

                # Build role-specific system instruction
                role_instruction = _build_role_system_instruction(role, student_data)

                if role == 'coordinator' or "total_students" in student_data:
                    dashboard_context = _generate_coordinator_summary(student_data)
                elif role == 'admin' or "total_users" in student_data:
                    dashboard_context = _generate_admin_summary(student_data)
                elif role == 'supervisor' or role == 'industry supervisor' or "total_assigned" in student_data:
                    dashboard_context = _generate_supervisor_summary(student_data)
                elif role == 'student' or "hours" in student_data:
                    dashboard_context = _generate_student_summary(student_data)
                else:
                    # Fallback — don't leak raw dict to LLM
                    dashboard_context = "\nUser Dashboard Info: Data available but role not recognized.\n"

                # Also include career briefing if it's a student
                if "hours" in student_data:
                    try:
                        career_briefing = generate_career_briefing(student_data)
                        dashboard_context = career_briefing + dashboard_context
                    except Exception as e:
                        logger.debug(f"Career briefing skipped: {e}")

            except Exception as ce:
                logger.error(f"[CHATBOT_HANDLER] Error generating dashboard summary: {ce}")

        if dashboard_context:
            import datetime
            current_time_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            text_for_llm = (
                f"[SYSTEM CONTEXT]\n"
                f"Current Local Time: {current_time_str}\n"
                f"{dashboard_context}\n\n"
                f"User Question: {text}"
            )
        else:
            text_for_llm = text

        logger.debug(f"[CHATBOT_HANDLER] Query for LLM: {text[:100]}...")
        logger.debug(f"[CHATBOT_HANDLER] Conversation history: {len(conversation_history)} messages")

        # Call the RAG pipeline with conversation context and role instruction
        result = generate_response(
            text_for_llm,
            conversation_history=conversation_history,
            role_instruction=role_instruction
        )

        # Add assistant response to context if successful
        if result.get("success") and result.get("answer"):
            context.add_assistant_message(result["answer"])

        # Add session_id to response
        result["session_id"] = session_id

        logger.info(f"[CHATBOT_HANDLER] Response generated successfully. Fallback: {result.get('is_fallback', False)}")

        return result

    except ImportError as e:
        error_msg = f"Import error - run_ai.py not found or cannot be imported: {str(e)}"
        logger.error(f"[CHATBOT_HANDLER ERROR] {error_msg}")
        logger.error(f"[CHATBOT_HANDLER ERROR] Traceback: {traceback.format_exc()}")

        return {
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE",
            "message": (
                "The chatbot service is temporarily unavailable. "
                "The AI assistant module cannot be loaded. "
                "Please contact the system administrator."
            ),
            "answer": None,
            "session_id": session_id,
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }

    except Exception as e:
        # Catch-all for any other errors
        error_msg = str(e)
        logger.error(f"[CHATBOT_HANDLER ERROR] {error_msg}")
        logger.error(f"[CHATBOT_HANDLER ERROR] Traceback: {traceback.format_exc()}")

        # Determine error type based on exception
        error_type = "CHATBOT_SERVICE_UNAVAILABLE"
        if "vector store" in error_msg.lower() or "vector_store" in error_msg.lower():
            error_type = "KNOWLEDGE_BASE_ERROR"
        elif "ollama" in error_msg.lower() or "model" in error_msg.lower():
            error_type = "LLM_ERROR"
        elif "embed" in error_msg.lower() or "embedding" in error_msg.lower():
            error_type = "EMBEDDING_ERROR"

        return {
            "success": False,
            "error_type": error_type,
            "message": (
                "The chatbot service is temporarily unavailable. "
                "Please try again later or contact your coordinator."
            ),
            "answer": None,
            "session_id": session_id,
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }


def _get_role_greeting(role: str) -> str:
    """Return a role-specific greeting message."""
    role = (role or "").lower().strip()

    if role == "student":
        return (
            "Hello! 👋 I'm your JRMSU OJT Assistant. I can help you with:\n\n"
            "- **Your OJT progress** — hours, attendance, and performance\n"
            "- **Requirements** — what you need to submit and when\n"
            "- **Guidelines** — dress code, policies, and procedures\n"
            "- **Performance insights** — based on your AI prediction data\n\n"
            "What would you like to know?"
        )

    elif role in ("supervisor", "industry supervisor"):
        return (
            "Hello! 👋 I'm the JRMSU OJT Assistant. As a supervisor, I can help you with:\n\n"
            "- **Student monitoring** — performance and attendance of your assigned students\n"
            "- **Evaluation guidance** — grading criteria and evaluation process\n"
            "- **OJT procedures** — policies and guidelines for industry supervisors\n\n"
            "How can I assist you today?"
        )

    elif role in ("coordinator", "ojt coordinator"):
        return (
            "Hello! 👋 I'm the JRMSU OJT Assistant. As a coordinator, I can help you with:\n\n"
            "- **Program overview** — student risk distribution and aggregate performance\n"
            "- **Student monitoring** — attendance compliance and task completion rates\n"
            "- **OJT policies** — requirements, grading, and administrative procedures\n\n"
            "What do you need help with?"
        )

    elif role == "admin":
        return (
            "Hello! 👋 I'm the JRMSU OJT Assistant. As an admin, I can help you with:\n\n"
            "- **System overview** — user stats, approvals, and platform status\n"
            "- **OJT policies** — institutional guidelines and procedures\n\n"
            "How can I help you?"
        )

    return "Hello! 👋 I'm the JRMSU OJT Assistant. How can I help you with your OJT today?"


def get_rag_context(user_message: str) -> str:
    """
    Retrieve relevant RAG context snippets for a user message.
    Used by the true Ollama streaming endpoint in server.py.
    """
    try:
        from run_ai import retrieve_context
        snippets = retrieve_context(user_message, top_k=3)
        if snippets:
            return "\n---\n".join(snippets)
        return "No specific JRMSU context found for this query."
    except Exception:
        return "General JRMSU OJT guidelines."
