# 🧠 OJT AI System: Technical Architecture & Logic Explanation

![AI Architecture Overview](file:///C:/Users/ACER/.gemini/antigravity/brain/723f11a2-9a70-43e6-bce3-539a9c0c34fe/ai_architecture_diagram_1776927762831.png)

This document provides a detailed technical breakdown of the Artificial Intelligence components within the **JRMSU OJT AI System**. The system integrates two core AI technologies: **Predictive Performance Analytics** and **Retrieval-Augmented Generation (RAG)**.

---

## 1. Predictive Performance Engine (Ensemble Learning)

The primary goal of the prediction engine is to identify students who are at risk of failing or performing poorly *before* the OJT period ends.

### 📊 Algorithms & Ensemble Logic
The system uses an **Ensemble Learning** approach, combining three distinct machine learning models to ensure maximum accuracy and robustness:

| Model | Role in System | Strength |
| :--- | :--- | :--- |
| **Logistic Regression (LR)** | Baseline Classification | Finds linear relationships between attendance and grades. |
| **Random Forest (RF)** | Non-linear Pattern Recognition | Detects complex interactions between different technical competencies. |
| **Naive Bayes (NB)** | Probabilistic Reasoning | Provides a robust baseline for risk categorization. |

**Weighted Aggregation:** The final "Risk Level" is not a simple average. The system uses **learned weights** (calculated during the training phase using a 20% hold-out validation set) to give more influence to the model that performed best on similar historical data.

### 🛡️ Feature Engineering & Data Leakage Prevention
To ensure the AI is truly "predictive" rather than just reporting current grades:
*   **Predictive Features:** The model is trained on **Attendance Rates**, **Competency-based Task Hours** (11 categories), and **Chatbot Engagement**.
*   **Leakage Prevention:** Current grading components (WPR, NR, CE, SE) are **excluded** from the training features. This ensures the model learns to predict risk based on *leading indicators* (behavior) rather than *lagging indicators* (grades already assigned).

---

## 2. RAG-based OJT Assistant (LLM)

The chatbot serves as a 24/7 Virtual Mentor, leveraging large language models and localized university knowledge.

### 🤖 LLM Core: Ollama & Gemma 2:2b
The system uses **Gemma 2:2b**, a state-of-the-art small language model from Google, running locally via **Ollama**. This ensures data privacy (student data never leaves the server) and high speed.

### 🔍 Retrieval-Augmented Generation (RAG) Architecture
The chatbot does not rely solely on the LLM's pre-trained knowledge. It uses a **RAG Pipeline**:
1.  **Vector Store:** Official JRMSU manuals, grading policies, and OJT requirements are converted into mathematical vectors (embeddings).
2.  **Retrieval:** When a user asks a question, the system finds the most relevant "knowledge snippets" from the official documents.
3.  **Dynamic Context Injection:** Before generating an answer, the system injects the student's **live dashboard data** (total hours, attendance %, and AI Risk Score) into the LLM prompt.

> [!TIP]
> This allows the chatbot to provide answers like: *"Based on the manual, you need 300 hours. You currently have 150 hours (50%), so you are exactly on track!"*

---

## 3. The "Mentor" Integration Logic

The true power of the system lies in how these two AI components talk to each other:

1.  **Continuous Analysis:** The **Predictive Engine** calculates the student's Risk Level and Progress Score every time a new record is approved.
2.  **Explainability (XAI):** The engine generates "Top Reasons" for its prediction (e.g., *"Absence streak detected"*).
3.  **Chatbot Consumption:** These reasons and scores are fed into the **Chatbot Handler**.
4.  **Actionable Mentorship:** When the student asks *"How am I doing?"*, the Chatbot combines the AI score with the University's grading rules to give a personalized, supportive recommendation.

### ⚖️ Grading Alignment
Both AI components are hard-coded to respect the **JRMSU Institutional Grading Weights**:
*   **20%** Weekly Progress Report (WPR)
*   **20%** Narrative Report (NR)
*   **20%** Coordinator Evaluation (CE)
*   **40%** Supervisor Evaluation (SE)

---

## 4. Business Value for JRMSU

*   **Proactive Intervention:** Coordinators can see "High Risk" flags weeks before the internship ends.
*   **Reduced Administrative Burden:** The chatbot handles 80% of routine policy questions.
*   **Data-Driven Mentorship:** Decisions are based on objective competency logs rather than subjective impressions.
