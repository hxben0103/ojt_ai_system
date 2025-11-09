import os
import re

# =========================================================
# Directory Setup
# =========================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "../models")
models_loaded = False

# =========================================================
# JRMSU Information Data
# =========================================================
JRMSU_DATA = {
    "history": (
        "Jose Rizal Memorial State University (JRMSU) is a premier state university located "
        "in Dapitan City, Zamboanga del Norte. It is known for academic excellence and its "
        "commitment to quality education and research."
    ),
    "location": "Dapitan Campus, Dapitan City, Zamboanga del Norte.",
    "mission": (
        "Jose Rizal Memorial State University pledges to deliver effective and efficient services "
        "in instruction, research, production, and extension — developing competent, innovative, and ethical individuals."
    ),
    "vision": (
        "A dynamic, inclusive, and regionally-diverse university in Southern Philippines, "
        "fostering innovation and transformative education."
    ),
    "goals": (
        "• Globally competitive academic programs\n"
        "• Resilient institutional systems\n"
        "• Innovative research and extension services\n"
        "• Partnerships with industries, HEIs, and communities\n"
        "• Strong fiscal and participatory governance"
    ),
    "core_values": "Humane Trust | Innovative Excellence | Transformational Communication",
    "quality_policy": (
        "JRMSU commits to providing quality and relevant education through efficient services "
        "aligned with national and international standards."
    ),
    "philosophy": (
        "Jose Rizal Memorial State University adheres to the principle of dynamism and cultural "
        "diversity in building a just and humane society."
    )
}

# =========================================================
# Display Functions
# =========================================================
def display_ojt_grading_system():
    return (
        "🎓 OJT Grading System\n"
        "------------------------------------------------------------\n"
        "Your OJT grade is computed based on the following components:\n\n"
        "• 20%  Weekly Progress Report\n"
        "• 20%  Narrative Report\n"
        "• 20%  Coordinator Evaluation\n"
        "• 40%  Supervisor Evaluation\n"
        "------------------------------------------\n"
        "The final grade is officially recorded in your Transcript of Records (TOR)."
    )

def display_learning_competencies():
    return (
        "🧠 OJT Learning Competencies and Activities\n"
        "------------------------------------------------------------\n"
        "Software Development — Design, create, and maintain software solutions.\n"
        "Machine Learning Engineering — Design and develop AI algorithms capable of learning and making predictions.\n"
        "IT-Related Research — Assist in research related to information technology and applied computing.\n"
        "User Experience / User Interface Design — Develop prototypes and layouts for client projects.\n"
        "Information Security Analysis — Monitor networks and support cybersecurity practices.\n"
        "Networking — Assist in network configuration, installation, and troubleshooting.\n"
        "Technical Support — Provide troubleshooting, repairs, and maintenance for computer systems.\n"
        "Data Analysis — Collect, process, and interpret organizational data.\n"
        "Customer Service — Communicate and coordinate with clients.\n"
        "Data Entry and Management — Maintain accurate database records.\n"
        "Office Work — Perform clerical and administrative tasks."
    )

def display_ojt_steps():
    return (
        "📋 Steps and Requirements for OJT\n"
        "------------------------------------------------------------\n"
        "1 – Identify a Host Training Establishment (HTE)\n"
        "2 – Coordinate with your OJT Coordinator and submit requirements\n"
        "3 – Apply to your chosen HTE and return with an approved MOA\n"
        "4 – Prepare 5 notarized copies of the final MOA\n"
        "5 – Secure requirements such as Parent’s Consent and Medical Certificate\n"
        "6 – Begin your OJT (Orientation, Training, DTR, Evaluation)\n"
        "7 – Submit Narrative Report and attend the Practicum Culmination"
    )

def display_dtr_format():
    return (
        "🕒 Daily Time Record (DTR) Guidelines\n"
        "------------------------------------------------------------\n"
        "The DTR is your official log of attendance during OJT.\n"
        "It should include:\n"
        "• Date and Day\n"
        "• Morning In / Out\n"
        "• Afternoon In / Out\n"
        "• Total Hours Rendered\n\n"
        "Each entry must be signed by your supervisor and validated by your OJT Coordinator.\n"
        "At the end of your OJT, compile it in the appendices of your Narrative Report."
    )

def display_narrative_report_format():
    return (
        "📝 Narrative Report Format and Writing Guide\n"
        "------------------------------------------------------------\n"
        "Chapter 1 – Company Profile\n"
        "Describe the background of your Host Training Establishment.\n\n"
        "Chapter 2 – Training Activities\n"
        "Detail your tasks, responsibilities, and skills learned.\n\n"
        "Chapter 3 – Results and Recommendations\n"
        "Summarize insights, reflections, and suggestions.\n\n"
        "Appendices – Supporting Documents (DTR, Evaluation Sheet, MOA, photos, etc.)"
    )

# =========================================================
# Multi-Match Learning Competency Predictor
# =========================================================
def predict_learning_competency(activity):
    if not activity or not activity.strip():
        return "Please describe the activity you'd like me to evaluate."

    activity = activity.lower().strip()

    weighted_keywords = {
        "Software Development": {
            "code": 2.0, "develop": 2.0, "program": 2.0, "software": 1.5,
            "system": 1.0, "design": 1.5, "test": 1.5, "debug": 1.5,
            "application": 1.5, "build": 1.5, "developed": 2.0, "creating": 1.5
        },
        "Machine Learning Engineering": {
            "ai": 2.0, "machine learning": 2.0, "predict": 1.5, "train": 2.0,
            "model": 1.5, "algorithm": 1.5, "automation": 1.0, "data pattern": 1.0
        },
        "IT-Related Research": {
            "research": 2.0, "study": 2.0, "survey": 1.5, "analyze": 1.5,
            "data gathering": 1.5, "documentation": 1.0, "report": 1.0
        },
        "User Experience / User Interface Design": {
            "design": 2.0, "prototype": 1.5, "figma": 2.0, "mockup": 1.5,
            "layout": 1.5, "interface": 1.5, "ui": 2.0, "ux": 2.0
        },
        "Information Security Analysis": {
            "security": 2.0, "firewall": 1.5, "scan": 1.0, "breach": 1.0,
            "protect": 1.5, "antivirus": 1.5, "monitor": 1.5, "vulnerability": 1.5
        },
        "Networking": {
            "network": 2.0, "router": 2.0, "cable": 1.5, "server": 1.0,
            "ip": 1.0, "configuration": 1.5, "connect": 1.5, "wifi": 1.5
        },
        "Technical Support": {
            "fix": 2.0, "repair": 2.0, "install": 1.5, "installation": 1.5,
            "troubleshoot": 2.0, "maintenance": 1.5, "support": 1.5,
            "computer": 1.5, "os": 1.5, "reformat": 2.0, "reinstalled": 1.8,
            "windows": 1.0, "setup": 1.0, "configure": 1.0
        },
        "Data Analysis": {
            "analyze": 2.0, "data": 2.0, "process": 1.5, "report": 1.0,
            "interpret": 1.5, "collect": 1.5, "excel": 1.5, "statistics": 1.5
        },
        "Customer Service": {
            "assist": 2.0, "client": 2.0, "customer": 2.0, "contact": 1.5,
            "inquiry": 1.5, "respond": 1.5, "call": 1.0, "communicate": 1.5
        },
        "Data Entry and Management": {
            "encode": 2.0, "file": 1.5, "database": 1.5, "record": 1.5,
            "data entry": 2.0, "input": 1.0, "update": 1.0, "manage": 1.5,
            "typing": 1.0, "spreadsheet": 1.0
        },
        "Office Work": {
            "print": 2.0, "photocopy": 2.0, "organize": 2.0, "organized": 2.0,
            "record": 1.5, "clerical": 1.5, "paperwork": 1.0, "file": 1.5,
            "documents": 2.0, "arrange": 1.5, "sort": 1.5, "folder": 1.0
        }
    }

    # Compute weighted matches
    scores = {}
    for comp, kw_dict in weighted_keywords.items():
        total = 0
        for kw, weight in kw_dict.items():
            if re.search(r"\b" + re.escape(kw) + r"\b", activity):
                total += weight
        if total > 0:
            scores[comp] = total

    if not scores:
        return "I couldn’t identify the learning competency. Please provide more details about your task."

    # Detect multiple top matches
    max_score = max(scores.values())
    threshold = max_score * 0.6
    top_matches = [comp for comp, score in scores.items() if score >= threshold]

    if len(top_matches) == 1:
        return f"Based on your described activity, your learning competency is **{top_matches[0]}**."
    else:
        combined = ", ".join(top_matches)
        return f"Based on your described activity, your learning competencies are **{combined}**."


# =========================================================
# Chatbot Logic
# =========================================================
def chatbot_response(user_input: str) -> str:
    text = user_input.lower().strip()

    # JRMSU Info
    for key, value in JRMSU_DATA.items():
        if key in text:
            label = key.title()
            return f"🏫 JRMSU {label}\n------------------------------------------------------------\n{value}"

    # OJT Sections
    if "grading" in text:
        return display_ojt_grading_system()
    if "competencies" in text and "predict" not in text:
        return display_learning_competencies()
    if "steps" in text or "requirements" in text:
        return display_ojt_steps()
    if "narrative" in text or "report" in text:
        return display_narrative_report_format()
    if "dtr" in text or "daily time record" in text:
        return display_dtr_format()

    # ✅ Smart Prediction Trigger
    if any(kw in text for kw in [
        "predict my learning competency",
        "predict based on my activity",
        "predict my daily activity",
        "predict competency",
        "determine my competency",
        "classify my activity",
        "analyze my activity"
    ]):
        # Extract quoted or inline activity
        match = re.search(r'["“](.*?)["”]', user_input)
        if match:
            activity = match.group(1)
            return predict_learning_competency(activity)

        # Try to capture natural-language activity
        parts = re.split(r"predict|based on|activity|competency|learning", text)
        if len(parts[-1].split()) > 3:
            return predict_learning_competency(parts[-1].strip())

        # Fallback: ask user
        activity = input("🧾 Please describe your activity: ")
        return predict_learning_competency(activity)

    # Default Response
    return (
        "I can assist you with JRMSU or OJT-related inquiries, such as grading, DTR, "
        "narrative writing, or learning competencies. If you'd like me to predict your "
        "learning competency, just say 'predict my learning competency' or describe your task."
    )

# =========================================================
# Terminal Mode
# =========================================================
if __name__ == "__main__":
    print("\n🤖 JRMSU OJT Assistant is now active.")
    print("Type 'exit' to close the assistant.\n")

    while True:
        query = input("You: ")
        if query.lower() in ["exit", "quit"]:
            print("👋 Session ended. Thank you for using JRMSU OJT Assistant.")
            break
        print(f"\nJRMSU OJT Assistant: {chatbot_response(query)}\n")