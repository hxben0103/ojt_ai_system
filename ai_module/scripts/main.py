import os
import csv
import joblib

# =========================================================
# JRMSU OJT Chatbot - Full Hybrid Version (TinyLLaMA + ML Integration)
# =========================================================

# 🧭 File Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "../data")
MODEL_DIR = os.path.join(BASE_DIR, "../models")

# Try loading hybrid models (Naive Bayes + Linear Regression)
try:
    vectorizer = joblib.load(os.path.join(MODEL_DIR, "tfidf.pkl"))
    nb_model = joblib.load(os.path.join(MODEL_DIR, "naive_bayes.pkl"))
    reg_model = joblib.load(os.path.join(MODEL_DIR, "linear_regression.pkl"))
    models_loaded = True
except:
    print("⚠️ Warning: Models not found. Please run train_hybrid_model.py first.")
    models_loaded = False


# =========================================================
# 🏫 JRMSU Information
# =========================================================
def display_jrmsu_info():
    print("\n🏫 Jose Rizal Memorial State University (JRMSU)")
    print("=" * 70)
    print("""
Republic of the Philippines
JOSE RIZAL MEMORIAL STATE UNIVERSITY
The Premier University in the Province of Zamboanga del Norte
Dapitan Campus, Dapitan City, Zamboanga del Norte

Core Values
• Humane Trust
• Innovative Excellence
• Transformational Communication

Vision:
A dynamic, inclusive and regionally-diverse university in Southern Philippines.

Mission:
Jose Rizal Memorial State University pledges to deliver effective and efficient
services along research, instruction, production, and extension. It commits itself
to provide advanced professional, technical and technopreneurial training with the
aim of producing highly competent, innovative and self-renewed individuals.

Goals:
G - Globally competitive educational institution
R - Resilient to internal and external risks and hazards
I - Innovative processes and solutions in research translated to extension engagements
P - Partnerships and collaborations with private enterprise, other HEIs, government agencies, and alumni
S - Sound Fiscal Management and Participatory Governance

Quality Policy Statement:
JRMSU provides quality training and development to students with adequate, suitable, and relevant
resources and services through an efficient and effective quality system conforming with national
and international standards.
    """)


# =========================================================
# 🧮 OJT Grading System
# =========================================================
def display_ojt_grading_system():
    print("\n🧮 OJT Grading System")
    print("=" * 70)
    print("""
You will be graded through the following criteria:

   20%  Weekly Progress Report
   20%  Practicum Narrative Report
   20%  Practicum Coordinator Evaluation
   40%  Practicum Partner Supervisor Evaluation
  100%  Final Grade

📘 The Final Grade will be reflected in your Transcript of Records (TOR).
    """)


# =========================================================
# 💻 OJT Learning Competencies
# =========================================================
def display_learning_competencies():
    print("\n💻 OJT Learning Competencies and Activities")
    print("=" * 70)
    print("""
• Software Development – Design, create, and maintain software solutions.
• Machine Learning Engineering – Develop AI algorithms and predictive models.
• IT Research – Assist in any IT-related research.
• UI/UX Design – Develop prototypes and user interface models.
• Information Security Analysis – Monitor network breaches and analyze incidents.
• Networking – Test, install, and maintain network devices.
• Technical Support – Perform troubleshooting and equipment maintenance.
• Data Analysis – Collect, verify, and interpret data.
• Customer Service – Communicate and assist clients.
• Data Entry & Management – Sort, maintain, and manage organizational data.
• Office Work – Answer calls, photocopy, record-keeping, and admin support.
    """)


# =========================================================
# 📋 OJT Steps & Requirements
# =========================================================
def display_ojt_steps():
    print("\n📋 Steps and Requirements for OJT")
    print("=" * 70)
    print("""
STEP 1 - Find a Host Training Establishment (HTE)
STEP 2 - Seek your OJT Coordinator (with Application Letter, Resume, Recommendation Letter, Draft MOA)
STEP 3 - Apply to the HTE and bring back accepted MOA
STEP 4 - Prepare 5 copies of the Final MOA (Notarized)
STEP 5 - Secure Requirements (Parent’s Consent, Medical Certificate, Lab Tests)
STEP 6 - Start the OJT (Orientation, Training, DTR, Evaluation)
STEP 7 - Practicum Culmination and Narrative Report Submission
    """)


# =========================================================
# 🧾 Evaluation Sheet Format
# =========================================================
def display_evaluation_sheet():
    print("\n📑 OJT Evaluation Sheet Format")
    print("=" * 70)
    print("""
The Evaluation Sheet is filled out by the student's immediate supervisor at the Host Training Establishment (HTE).
It assesses performance in areas like:

• Attendance & Punctuality  
• Cooperation & Teamwork  
• Knowledge & Skill Application  
• Quality & Quantity of Work  
• Communication & Work Attitude  

Each criterion is scored (1–5) and signed by the supervisor.
This contributes to your final OJT grade.
    """)


# =========================================================
# 🕒 Daily Time Record (DTR)
# =========================================================
def display_dtr_format():
    print("\n🕒 Daily Time Record (DTR) Format")
    print("=" * 70)
    print("""
Your DTR logs attendance during OJT.

Includes:
• Date and Day  
• Morning In/Out  
• Afternoon In/Out  
• Total Hours  

Must be signed by the immediate supervisor and validated by the OJT Coordinator.
    """)


# =========================================================
# 📝 Narrative Report Writing Guide
# =========================================================
def display_narrative_report_format():
    print("\n📘 Narrative Report Format and Writing Guide")
    print("=" * 70)
    print("""
📕 Structure:
- Cover Page, Acknowledgment, Dedication, Table of Contents

Chapter 1: Host Training Establishment Profile  
Chapter 2: Training Activities and Experiences  
Chapter 3: Results, Findings, and Recommendations  
Appendices: DTR, Evaluation Sheet, MOA, Photos, etc.

✏️ Tips:
• Use formal tone and first-person view  
• Proofread carefully  
• Print on long bond paper with proper formatting
    """)


# =========================================================
# 🤖 Predict Learning Competency (Rule + Hybrid Model)
# =========================================================
def predict_learning_competency(activity):
    activity = activity.lower()

    keywords = {
        "Software Development": ["code", "program", "develop", "system", "debug", "website"],
        "Machine Learning": ["train", "predict", "ai", "model", "pattern"],
        "IT Research": ["research", "study", "survey"],
        "UI/UX Design": ["design", "prototype", "figma", "layout"],
        "Information Security": ["security", "firewall", "scan", "breach"],
        "Networking": ["install", "router", "network", "server"],
        "Technical Support": ["repair", "troubleshoot", "fix", "maintenance"],
        "Data Analysis": ["data", "analyze", "chart", "excel"],
        "Customer Service": ["assist", "client", "customer", "call"],
        "Office Work": ["file", "photocopy", "encode", "record", "documents"]
    }

    # Step 1: Rule-based detection
    for comp, words in keywords.items():
        if any(word in activity for word in words):
            return f"✅ Based on your activity, your learning competency is: **{comp}**."

    # Step 2: ML hybrid prediction (if model available)
    if models_loaded:
        vec = vectorizer.transform([activity])
        nb_pred = nb_model.predict(vec)[0]
        reg_pred = reg_model.predict(vec)[0]
        return f"🧠 ML Prediction → Naive Bayes: {nb_pred}, Linear Regression Score: {reg_pred:.2f}"

    return "⚠️ I couldn’t determine the competency. Please describe your activity in more detail."


# =========================================================
# 💬 Chatbot Response
# =========================================================
def chatbot_response(user_input):
    user_input = user_input.lower()

    if "about jrmsu" in user_input:
        display_jrmsu_info()
    elif "grading" in user_input:
        display_ojt_grading_system()
    elif "competencies" in user_input or "activities" in user_input:
        display_learning_competencies()
    elif "steps" in user_input or "requirements" in user_input:
        display_ojt_steps()
    elif "evaluation" in user_input:
        display_evaluation_sheet()
    elif "dtr" in user_input or "daily time record" in user_input:
        display_dtr_format()
    elif "narrative" in user_input or "report" in user_input:
        display_narrative_report_format()
    elif "predict" in user_input or "activity" in user_input:
        activity = input("🧾 Please describe your daily activity: ")
        print(predict_learning_competency(activity))
    else:
        print("⚠️ Sorry, I can only answer JRMSU OJT-related questions.")


# =========================================================
# 🚀 Main Function
# =========================================================
def main():
    print("\n🤖 Welcome to JRMSU OJT Chatbot System")
    print("This chatbot provides official guidance about JRMSU OJT processes.")
    print("Type 'exit' to quit.\n")

    while True:
        user_input = input("🧑 You: ")
        if user_input.lower() in ["exit", "quit"]:
            print("👋 Thank you! Have a great day, JRMSU student!")
            break
        chatbot_response(user_input)


if __name__ == "__main__":
    main()

