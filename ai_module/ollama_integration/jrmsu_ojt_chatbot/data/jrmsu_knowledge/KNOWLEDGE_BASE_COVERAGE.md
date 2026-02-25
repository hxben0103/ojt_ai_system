# JRMSU OJT Knowledge Base Coverage

This document tracks the coverage of the knowledge base for common OJT-related questions.

## Current Coverage

### ✅ Covered Topics

1. **University Information**
   - `jrmsu_mission.txt` - University mission statement
   - `jrmsu_vision.txt` - University vision statement
   - `jrmsu_goals.txt` - University goals
   - `jrmsu_core_values.txt` - University core values
   - `history.txt` - University history
   - `university_profile.txt` - University profile
   - `university_officials.txt` - University officials

2. **OJT Program Information**
   - `ojt_requirements.txt` - OJT requirements and prerequisites
   - `ojt_grading_system.txt` - OJT grading and evaluation system
   - `narrative_report.txt` - Narrative report requirements
   - `procedures.txt` - General OJT procedures

3. **Documentation & Forms**
   - `documents_summary.txt` - Summary of required documents
   - `Evaluation Sheet.txt` - Evaluation sheet information
   - `Excuse Slip.txt` - Excuse slip procedures
   - `Memorandum of Agreement.txt` - MOA information
   - `Parent's Waiver and Consent Form.txt` - Waiver form information
   - `Recommendation Letter for OJT Deployment.txt` - Recommendation letter info

4. **College-Specific**
   - `ccs_overview.txt` - College of Computer Studies overview
   - `ccs_officials.txt` - CCS officials
   - `competencies.txt` - Competency requirements

5. **Guidelines**
   - `dtr_guidelines.txt` - Daily Time Record guidelines
   - `quality_policy.txt` - Quality policy

## Partially Covered Topics

### ⚠️ Needs Enhancement

1. **Attendance Policies**
   - `dtr_guidelines.txt` exists but may need:
     - Late attendance policies and consequences
     - Absence policy and maximum allowed absences
     - Tardiness rules
     - Make-up time procedures

2. **Required Hours**
   - Information may be in `ojt_requirements.txt` but needs verification for:
     - Total required hours (e.g., 200, 400 hours)
     - Minimum hours per day/week
     - Overtime policies
     - Hours distribution across semesters

## Missing Topics (Recommended Additions)

### ❌ Not Yet Covered

1. **Late Attendance Policy** (RECOMMENDED: `late_attendance_policy.txt`)
   - What happens if a student is late?
   - How many late arrivals are allowed?
   - Consequences of excessive lateness
   - Make-up procedures for lateness

2. **Absence Policy** (RECOMMENDED: `absence_policy.txt`)
   - Maximum number of absences allowed
   - Excused vs. unexcused absences
   - Procedures for reporting absences
   - Documentation required for absences
   - Make-up time for absences

3. **Required Hours Details** (RECOMMENDED: `required_hours_details.txt`)
   - Total hours required (specific number)
   - Minimum hours per day
   - Minimum hours per week
   - How hours are tracked
   - Overtime policies and limits
   - Distribution across OJT period

4. **Dress Code** (RECOMMENDED: `dress_code.txt`)
   - Appropriate attire for OJT
   - Industry-specific dress requirements
   - What to do if dress code is unclear
   - Consequences of dress code violations

5. **Clearance Procedures** (RECOMMENDED: `clearance_procedures.txt`)
   - Steps for OJT clearance
   - Required signatures
   - Timeline for clearance
   - Who to contact for clearance

6. **Report Deadlines** (RECOMMENDED: `report_deadlines.txt`)
   - Weekly report deadlines
   - Monthly report deadlines
   - Narrative report submission deadline
   - Evaluation submission deadlines
   - Late submission penalties

7. **Supervisor Communication** (RECOMMENDED: `supervisor_communication.txt`)
   - How to communicate with supervisors
   - When to contact coordinator
   - Emergency contact procedures
   - Reporting issues or concerns

## How to Add Missing Topics

1. Create a new `.txt` file in this directory (`jrmsu_knowledge/`)
2. Add the topic content in plain text format
3. Rebuild the vector store:
   ```bash
   cd ai_module/ollama_integration/jrmsu_ojt_chatbot/rag
   python build_rag.py
   ```
4. Test the chatbot to ensure it can answer questions about the new topic
5. Update this document to mark the topic as covered

## Priority Recommendations

### High Priority (Add Soon)
1. Late attendance policy
2. Absence policy
3. Required hours details

### Medium Priority
4. Dress code
5. Clearance procedures
6. Report deadlines

### Low Priority (Nice to Have)
7. Supervisor communication guidelines

---

**Last Updated**: 2024-01-XX
**Maintained By**: OJT System Administrator

