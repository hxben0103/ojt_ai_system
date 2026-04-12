# Chapter 4: PlantUML Diagrams (Fixed)

You can copy and paste the following blocks into any PlantUML editor (like [PlantText](https://www.planttext.com/) or [PlantUML Online](https://www.plantuml.com/plantuml/)).

## A. Predictive Analytics Algorithm
```plantuml
@startuml
title Predictive Analytics Algorithm (Ensemble ML)

start
:Student Snapshot Data;
:Pre-processing & Feature Scaling;

fork
  :Logistic Regression Model\n(40% Weight);
fork again
  :Random Forest Model\n(40% Weight);
fork again
  :Naive Bayes Model\n(20% Weight);
end fork

:Combine Class Probabilities;
:Weighted Averaging Ensemble Hub;
:Final Risk Level Prediction;
stop
@enduml
```

---

## B. AI Prediction and Insight Generation
```plantuml
@startuml
title AI Prediction and Insight Generation Flow

package "Data Collection" {
  [Attendance Records] as Att
  [Supervisor Evaluations] as Eval
  [Narrative Reports] as Narr
}

node "Node.js Backend" {
  [Snapshot Generation] as Snap
}

node "Python AI Module" {
  [Ensemble Prediction Logic] as Logic
}

database "PostgreSQL" {
  [ai_insights Table] as DB
}

node "Flutter Dashboard" {
  [Risk Badges] as UI
}

Att -> Snap
Eval -> Snap
Narr -> Snap

Snap -> Logic : JSON Payload
Logic -> DB : Prediction Results
DB -> UI : Real-time Updates
@enduml
```

---

## C. Conversational AI (Chatbot Support)
```plantuml
@startuml
title Conversational AI Interaction Sequence

actor Student
participant "Flutter Frontend" as Flutter
participant "Flask AI Module" as Flask
participant "Node.js Backend" as Backend
database "PostgreSQL" as DB

Student -> Flutter : Type OJT Query
Flutter -> Flask : POST /chat
activate Flask
Flask -> Flask : Process KB
Flask --> Flutter : Bot Response
deactivate Flask
Flutter --> Student : Display Response

group Logging
    Flutter -> Backend : Log Interaction
    Backend -> DB : Store
end
@enduml
```

---

## D. System Integration Architecture
```plantuml
@startuml
title System Integration Architecture

node "Frontend (Flutter)" as Flutter
node "Backend (Node.js)" as NodeJS
node "AI Hub (Python)" as AI
database "PostgreSQL" as DB

Flutter -> NodeJS : HTTP Request
NodeJS -> Flutter : Response

NodeJS -> DB : SQL
DB -> NodeJS : Results

NodeJS -> AI : Request
AI -> NodeJS : Result

Flutter -> AI : Chat API
@enduml
```

---

## E. System Innovation Framework
```plantuml
@startuml
title System Innovation Framework

skinparam componentStyle rectangle

rectangle "SYSTEM INNOVATION HUB" as Hub #LightBlue

package "Automation" {
  [Geofencing] as A1
  [Trust Scoring] as A2
  [Auto-DTR] as A3
}

package "Predictive Analytics" {
  [Risk Assessment] as P1
  [Ensemble ML] as P2
  [Forecasting] as P3
}

package "Conversational AI" {
  [Chatbot KB] as C1
  [Guidance] as C2
  [Analytics] as C3
}

A1 -> Hub
A2 -> Hub
A3 -> Hub

P1 -> Hub
P2 -> Hub
P3 -> Hub

C1 -> Hub
C2 -> Hub
C3 -> Hub

Hub -> [Success]
@enduml
```

---

## F. Chatbot Decision Logic Flow (Verified)
```plantuml
@startuml
title Chatbot Decision Logic Flow (Verified)

start
:User Message Received;
if (Is Input Valid?) then (No)
  :Return Validation Error;
  stop
endif

if (Is Simple Greeting?) then (Yes)
  :Return Friendly Greeting;
  stop
endif

if (Is Official JRMSU Info?) then (Yes)
  :Return Exact Text from KB File;
  stop
endif

:Detect Intent (Attendance/Performance);
:Inject Role-Based Dashboard Context;
:Retrieve Top 3 Knowledge Chunks (RAG);

if (Similarity Score > 0.15?) then (No)
  :Return Fallback / Apology Message;
  stop
endif

:Generate Augmented LLM Prompt;
:AI Model Inference (Gemma 2:2b);
:Clean Meta-References & Logic Check;
:Return Intelligent Response;
stop
@enduml
```
