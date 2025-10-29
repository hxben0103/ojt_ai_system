import pandas as pd, joblib
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.linear_model import LinearRegression

# --- Naive Bayes for competencies ---
act = pd.read_csv("../data/ojt_activities.csv")
X_train, _, y_train, _ = train_test_split(act["activity_text"], act["competency_label"], random_state=42)
vec = TfidfVectorizer(stop_words="english")
X_train_vec = vec.fit_transform(X_train)
nb = MultinomialNB().fit(X_train_vec, y_train)

# --- Regression for grades ---
sc = pd.read_csv("../data/ojt_scores.csv")
X = sc[["weekly_report","narrative","coordinator_eval","supervisor_eval"]]
y = sc["final_grade"]
reg = LinearRegression().fit(X, y)

# --- Save models ---
joblib.dump(vec, "../models/tfidf.pkl")
joblib.dump(nb, "../models/naive_bayes.pkl")
joblib.dump(reg, "../models/linear_regression.pkl")
print("✅ Models trained and saved!")
