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
   - `late_attendance_policy.txt` - Late attendance rules and consequences
   - `absence_policy.txt` - Absence and notification policy
   - `required_hours_details.txt` - Hour requirements by program

3. **Documentation & Forms**
   - `documents_summary.txt` - Summary of required documents
   - `Evaluation Sheet.txt` - Evaluation sheet information
   - `Excuse Slip.txt` - Excuse slip procedures
   - `Memorandum of Agreement.txt` - MOA information
   - `Parent's Waiver and Consent Form.txt` - Waiver form information
   - `Recommendation Letter for OJT Deployment.txt` - Recommendation letter info
   - `clearance_procedures.txt` - Steps for final OJT clearance

4. **College-Specific**
   - `ccs_overview.txt` - College of Computer Studies overview
   - `ccs_officials.txt` - CCS officials
   - `competencies.txt` - Competency requirements

5. **Guidelines**
   - `dtr_guidelines.txt` - Daily Time Record guidelines
   - `quality_policy.txt` - Quality policy
   - `dress_code.txt` - Grooming and professional attire

## Partially Covered Topics

### ⚠️ Needs Enhancement

(None at this time)

## Missing Topics (Recommended Additions)

### ❌ Not Yet Covered

1. **Supervisor Communication** (RECOMMENDED: `supervisor_communication.txt`)
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

