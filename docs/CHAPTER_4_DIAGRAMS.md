# Chapter 4: System Innovation and Contribution - Diagrams

This document contains the conceptual and technical diagrams for the OJT AI System as part of Chapter 4 of the project documentation.

## A. Predictive Analytics Algorithm
The system utilizes an **Ensemble Machine Learning** approach, combining three distinct algorithms to ensure high accuracy and robust risk prediction for student performance.

```mermaid
graph TD
    Data[Student Snapshot Data] --> Pre[Pre-processing & Scaling]
    Pre --> Model1[Logistic Regression Model (40% Weight)]
    Pre --> Model2[Random Forest Model (40% Weight)]
    Pre --> Model3[Naive Bayes Model (20% Weight)]
    
    Model1 --> Prob1[Class Probabilities]
    Model2 --> Prob2[Class Probabilities]
    Model3 --> Prob3[Class Probabilities]
    
    Prob1 --> Ensemble[Weighted Averaging Ensemble Hub]
    Prob2 --> Ensemble
    Prob3 --> Ensemble
    
    Ensemble --> Final[Final Risk Level Prediction: HIGH / MEDIUM / LOW]
```

---

## B. AI Prediction and Insight Generation
This diagram illustrates the flow from raw data collection to the generation of actionable insights and performance badges.

```mermaid
graph LR
    subgraph Input_Data [Data Collection]
    A[Attendance Records]
    E[Supervisor Evaluations]
    N[Narrative Reports]
    end
    
    Input_Data --> BE[Node.js Backend]
    BE --> Snapshot[Student Snapshot Generation]
    Snapshot --> AI[Python AI Module]
    AI --> Logic[Ensemble Prediction Logic]
    Logic --> Result[Risk Level & Confidence Score]
    
    Result --> Store[PostgreSQL ai_insights Table]
    Store --> UI[Flutter Dashboard: Risk Badges & Notifications]
```

---

## C. Conversational AI (Chatbot Support)
The interaction flow for the AI chatbot, demonstrating both automated response generation and secure interaction logging.

```mermaid
sequenceDiagram
    participant S as Student / User
    participant F as Flutter Frontend
    participant AI as Flask AI Module
    participant BE as Node.js Backend
    participant DB as PostgreSQL (Logs)

    S->>F: Types OJT-related Query
    F->>AI: POST /chat (User Message)
    AI->>AI: Process Knowledge Base (Rule-based)
    AI-->>F: Return Bot Response
    F-->>S: Display Response in UI
    F->>BE: POST /api/prediction/chatbot/logs
    BE->>DB: Store Interaction (Query/Response/Time)
```

---

## D. System Integration Architecture
A high-level view of the four core pillars of the system and how they communicate.

```mermaid
graph TB
    subgraph Users [User Interfaces]
    F[Flutter Cross-Platform App]
    end
    
    subgraph Server [API Server]
    BE[Node.js / Express.js]
    end
    
    subgraph Data [Data Persistence]
    DB[(PostgreSQL Database)]
    end
    
    subgraph Intel [Intelligence Hub]
    AI[Python / Flask AI Module]
    end
    
    F <-->|"HTTP / JWT Auth"| BE
    BE <-->|"SQL / Stored Procedures"| DB
    BE <-->|"HTTP / JSON Payload"| AI
    F <-->|"Direct Chat API"| AI
```

---

## E. System Innovation Framework
The conceptual innovation of the system, where three independent technologies are integrated to create a smarter OJT management environment.

```mermaid
graph TD
    A[Automation] --> Hub[SYSTEM INNOVATION HUB]
    P[Predictive Analytics] --> Hub
    C[Conversational AI] --> Hub
    
    subgraph Automation_Pillar
    A1[Location Geofencing]
    A2[Trust Scoring]
    A3[Auto-DTR Generation]
    end
    
    subgraph Analytics_Pillar
    P1[Risk Assessment]
    P2[Ensemble ML Models]
    P3[Performance Forecasting]
    end
    
    subgraph AI_Pillar
    C1[Query Knowledge Base]
    C2[Real-time Guidance]
    C3[Interaction Analytics]
    end

    A1 -.-> A
    A2 -.-> A
    A3 -.-> A
    P1 -.-> P
    P2 -.-> P
    P3 -.-> P
    C1 -.-> C
    C2 -.-> C
    C3 -.-> C
    
    Hub --> Out[Enhanced OJT Monitoring & Student Success]
```

---

## F. Chatbot Decision Logic Flow (Verified)
This flowchart represents the **actual implementation** of the AI's internal decision-making process in the `chatbot_handler.py` and `run_ai.py` modules.

```mermaid
flowchart TD
    Start([User Message Received]) --> Input{Input Valid?}
    Input -- No --> Err[Return Validation Error]
    Input -- Yes --> Greet{Is Greeting?}
    
    Greet -- Yes --> Static[Return Friendly Greeting]
    Greet -- No --> Official{Is Official info?\nMission/Vision/etc.}
    
    Official -- Yes --> Exact[Return Exact Text\nfrom Knowledge File]
    Official -- No --> Context[Inject Role-Based\nDashboard Context]
    
    Context --> RAG[Retrieve Knowledge Base\nContext - RAG]
    RAG --> Score{Similarity\nScore > 0.15?}
    
    Score -- No --> Fall[Return Fallback\nApology Message]
    Score -- Yes --> Gemma[Execute LLM Inference\nGemma 2:2b]
    
    Gemma --> Cleanup[Clean Meta-References\n& Format Text]
    Cleanup --> Resp([Return Intelligent Response])
    Exact --> Resp
    Static --> Resp
```
