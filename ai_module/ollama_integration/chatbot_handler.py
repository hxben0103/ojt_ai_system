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
from typing import Dict, Any, Optional, List

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
# OJT Topic Guard — Only answer OJT/JRMSU related queries
# ──────────────────────────────────────────────────────────────
OJT_TOPIC_KEYWORDS = [
    # OJT terms
    "ojt", "internship", "practicum", "on the job", "on-the-job", "training",
    "deployment", "host company", "industry partner",
    # Attendance / DTR
    "attendance", "dtr", "daily time record", "hours", "time in", "time out",
    "overtime", "log", "check in", "check out", "present", "absent",
    # Requirements / Documentation
    "requirement", "journal", "narrative", "narrative report", "documentation",
    "submission", "deadline", "clearance", "completion", "weekly progress",
    # Grading / Performance
    "grade", "grading", "evaluation", "performance", "score", "risk",
    "prediction", "forecast", "ai", "insight", "analytics",
    # People / Roles
    "supervisor", "coordinator", "student", "admin",
    # Tasks / Competencies
    "competency", "competencies", "task", "daily task", "work", "activity",
    # University / Institution
    "jrmsu", "university", "college", "ccs", "campus",
    "mission", "vision", "goals", "core values", "quality policy",
    "history", "profile", "officials",
    # Policies
    "schedule", "dress code", "attire", "uniform", "policy", "rules",
    "late", "tardy", "tardiness", "excuse", "waiver",
    # System / Dashboard
    "dashboard", "progress", "status", "my",
    # Career
    "career", "skill", "job", "employability",
    # General help triggers (allowed because they likely lead to OJT topics)
    "help", "how", "what", "when", "where", "who", "why",
    "can i", "do i", "should i", "am i", "tell me",
    "explain", "guide", "advise", "recommend",
]

# Queries that are clearly off-topic
OFF_TOPIC_INDICATORS = [
    "weather", "recipe", "movie", "game", "song", "music",
    "sports", "news", "politics", "celebrity", "joke",
    "translate", "code", "program", "python", "javascript",
    "math problem", "solve", "calculate",
    "love", "dating", "relationship",
    "bitcoin", "crypto", "stock", "invest",
]

# GAP 5 FIX — Canonical wording aligned to system prompt spec
OJT_DECLINE_MESSAGE = (
    "Sorry, I can only answer OJT-related questions based on system data."
)

# GAP 1 FIX — Explicit no-data response when student_data is absent
NO_DATA_MESSAGE = "No available data found in the system."

# GAP 2 FIX — Role whitelist for escalation guard
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


def _is_ojt_related(text: str) -> bool:
    """
    Check if the query is related to OJT, JRMSU, or the system's scope.
    Returns True if the query should be processed, False if it should be declined.
    """
    text_lower = text.lower().strip()

    # Very short queries (1-3 words) — allow them through, the RAG will handle
    if len(text_lower.split()) <= 3:
        return True

    # Check for off-topic indicators first
    for indicator in OFF_TOPIC_INDICATORS:
        if indicator in text_lower:
            logger.info(f"[TOPIC_GUARD] Blocked off-topic query: matched '{indicator}'")
            return False

    # Check for OJT keywords
    for keyword in OJT_TOPIC_KEYWORDS:
        if keyword in text_lower:
            return True

    # If no OJT keywords found in a longer query, it's likely off-topic
    if len(text_lower.split()) > 5:
        logger.info(f"[TOPIC_GUARD] No OJT keywords found in query: {text_lower[:80]}")
        return False

    # Short-medium queries without clear indicators — allow them through
    # The RAG confidence check will catch truly irrelevant ones
    return True


# ──────────────────────────────────────────────────────────────
# Intent Detection
# ──────────────────────────────────────────────────────────────
def _detect_intent(text: str) -> str:
    """Detect the high-level intent of the user message."""
    text_lower = text.lower()

    performance_keywords = ["performance", "risk", "score", "grade", "forecast", "prediction", "how am i doing", "status"]
    if any(k in text_lower for k in performance_keywords):
        return "PERFORMANCE"

    attendance_keywords = ["attendance", "dtr", "hours", "late", "absent", "log"]
    if any(k in text_lower for k in attendance_keywords):
        return "ATTENDANCE"

    requirements_keywords = ["requirement", "journal", "documentation", "submission", "deadline"]
    if any(k in text_lower for k in requirements_keywords):
        return "REQUIREMENTS"

    dashboard_keywords = ["dashboard", "my progress", "my stats", "hours", "total students", "risk", "status", "pending", "evaluation"]
    if any(k in text_lower for k in dashboard_keywords):
        return "DASHBOARD"

    return "GENERAL"


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
            "Use a supportive, mentoring tone. When dashboard data is available, "
            "reference their actual hours, attendance, and performance score to give "
            "personalized advice. Always relate your answers to their OJT progress. "
            "You must ONLY answer questions related to OJT, JRMSU, and academic matters. "
            "If the question is outside this scope, politely decline."
        )

    elif role == "supervisor" or role == "industry supervisor":
        return (
            "You are the JRMSU OJT Assistant speaking to an **Industry Supervisor**. "
            "Use a professional, collegial tone. When dashboard data is available, "
            "reference the students assigned to them, pending evaluations, and any "
            "high-risk students that need attention. Help them understand the OJT "
            "grading system, evaluation process, and student monitoring. "
            "You must ONLY answer questions related to OJT, JRMSU, and academic matters. "
            "If the question is outside this scope, politely decline."
        )

    elif role == "coordinator" or role == "ojt coordinator":
        return (
            "You are the JRMSU OJT Assistant speaking to an **OJT Coordinator**. "
            "Use a professional, administrative tone. When dashboard data is available, "
            "reference system-wide statistics like total students, risk distribution, "
            "average attendance, and completion rates to provide actionable insights. "
            "Help them with student management, policy enforcement, and program oversight. "
            "You must ONLY answer questions related to OJT, JRMSU, and academic matters. "
            "If the question is outside this scope, politely decline."
        )

    elif role == "admin":
        return (
            "You are the JRMSU OJT Assistant speaking to a **System Administrator**. "
            "Use a formal, technical tone. When dashboard data is available, "
            "reference user counts, approval queues, and system metrics. "
            "Help them with administrative oversight of the OJT platform. "
            "You must ONLY answer questions related to OJT, JRMSU, and academic matters. "
            "If the question is outside this scope, politely decline."
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
        f"ASSESSMENT: This student is {perf_assessment}. They have {att_assessment}.\n"
    )

    if not can_act:
        blocking = data.get('blocking_reason', 'OJT setup incomplete')
        summary += f"⚠️ OJT BLOCKED: {blocking}\n"

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

    summary = (
        f"\n[COORDINATOR PROGRAM DATA]\n"
        f"Total Students Under Supervision: {total}\n"
        f"Risk Distribution: {high_risk} High Risk, {medium_risk} Medium Risk, {low_risk} Low Risk\n"
        f"OJT Status: {active} Active, {completed} Completed\n"
        f"Average Attendance Rate: {avg_attendance:.1f}%\n"
        f"Average Completion Ratio: {avg_completion:.1f}%\n"
        f"Average Forecasted Grade: {avg_grade}\n"
    )

    # GAP 4 — Auto-detect trends and common issues from student details
    if student_details:
        frequent_absent = [s.get('name', 'Unknown') for s in student_details if (s.get('days_absent') or 0) > 3]
        high_tardiness = [s.get('name', 'Unknown') for s in student_details if (s.get('late_count') or 0) > 5]
        low_score = [s.get('name', 'Unknown') for s in student_details if (s.get('score') or 0) < 60]
        low_attendance = [s.get('name', 'Unknown') for s in student_details if (s.get('attendance_rate') or 0) < 70]

        trend_flags = []
        if frequent_absent:
            trend_flags.append(
                f"{len(frequent_absent)} student(s) with >3 absences: {', '.join(frequent_absent)}"
            )
        if high_tardiness:
            trend_flags.append(
                f"{len(high_tardiness)} student(s) with >5 late arrivals: {', '.join(high_tardiness)}"
            )
        if low_score:
            trend_flags.append(
                f"{len(low_score)} student(s) with AI score below 60: {', '.join(low_score)}"
            )
        if low_attendance:
            trend_flags.append(
                f"{len(low_attendance)} student(s) with attendance rate below 70%: {', '.join(low_attendance)}"
            )

        if trend_flags:
            summary += "\nTrend Flags / Common Issues Detected:\n"
            for flag in trend_flags:
                summary += f"⚠️ {flag}\n"
        else:
            summary += "\nTrend Flags: No critical issues detected across all students.\n"

        summary += "\nPer-Student Performance Data:\n"
        for s in student_details:
            name = s.get('name', 'Unknown')
            risk = s.get('risk_level', 'N/A')
            score = s.get('score', 'N/A')
            hrs_done = s.get('hours_completed', 0)
            hrs_req = s.get('hours_required', 300)
            att_rate = s.get('attendance_rate', 0)
            present = s.get('days_present', 0)
            absent = s.get('days_absent', 0)
            late = s.get('late_count', 0)
            grade = s.get('forecasted_grade')
            status = s.get('status', 'Active')
            company = s.get('company', 'N/A')
            supervisor = s.get('supervisor', 'N/A')

            grade_str = f"{grade:.1f}" if grade else 'N/A'
            summary += (
                f"- {name} (Status: {status}, Company: {company}, Supervisor: {supervisor})\n"
                f"  Hours: {hrs_done}/{hrs_req}, Attendance: {att_rate}% ({present} present, {absent} absent, {late} late)\n"
                f"  AI Score: {score}/100, Risk: {risk}, Forecasted Grade: {grade_str}\n"
            )

    return summary


# Risk sort order for supervisor summary
_RISK_ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}


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
            key=lambda s: _RISK_ORDER.get((s.get('risk_level') or 'LOW').upper(), 2)
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

    # Check for simple greetings - return friendly role-aware response without RAG
    greeting_patterns = [
        "hi", "hello", "hey", "good morning", "good afternoon",
        "good evening", "greetings", "hi there", "hello there"
    ]
    text_lower = text.lower().strip()

    if text_lower in greeting_patterns or any(text_lower.startswith(g) for g in greeting_patterns):
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
    if not _is_ojt_related(text):
        logger.info(f"[CHATBOT_HANDLER] Declined off-topic query: {text[:80]}")
        return {
            "success": True,
            "answer": OJT_DECLINE_MESSAGE,
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

        # Detect intent
        intent = _detect_intent(text)
        logger.info(f"[CHATBOT_HANDLER] Detected intent: {intent}")

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
                    # Fallback for generic "User" role if data is present
                    dashboard_context = f"\nUser Dashboard Info: {str(student_data)}\n"

                # Also include career briefing if it's a student
                if "hours" in student_data:
                    try:
                        career_briefing = generate_career_briefing(student_data)
                        dashboard_context = career_briefing + dashboard_context
                    except Exception as e:
                        logger.debug(f"Career briefing skipped: {e}")

            except Exception as ce:
                logger.error(f"[CHATBOT_HANDLER] Error generating dashboard summary: {ce}")

        # ── Build enriched query for LLM ──
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

        logger.info(f"[CHATBOT_HANDLER] Processing message for session {session_id}")
        logger.debug(f"[CHATBOT_HANDLER] Message: {text[:100]}...")
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
