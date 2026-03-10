import numpy as np
import pickle
import os
from sklearn.ensemble import IsolationForest

def train_and_save():
    print("🚀 Training Integrity Model (Isolation Forest)...")
    
    # Generate synthetic baseline data representing "normal" behavior
    # Features: [distance_from_geofence_m, accuracy_m, has_photo_int]
    
    np.random.seed(42)
    
    # Normal check-ins: close to geofence (< 50m), good accuracy (< 20m), has photo (1)
    distance_normal = np.abs(np.random.normal(loc=15.0, scale=15.0, size=1000))
    accuracy_normal = np.abs(np.random.normal(loc=10.0, scale=5.0, size=1000))
    has_photo_normal = np.ones(1000)
    
    normal_data = np.column_stack((distance_normal, accuracy_normal, has_photo_normal))
    
    model = IsolationForest(contamination=0.05, random_state=42)
    model.fit(normal_data)
    
    # Save the model
    models_dir = os.path.join(os.path.dirname(__file__), "..", "models")
    os.makedirs(models_dir, exist_ok=True)
    
    model_path = os.path.join(models_dir, "integrity_model.pkl")
    with open(model_path, 'wb') as f:
        pickle.dump(model, f)
        
    print(f"✅ Integrity Model saved to {model_path}")
    
    # Test cases
    print("\n🧪 Testing anomalies:")
    
    # 1. Normal
    normal_case = np.array([[10.0, 15.0, 1]])
    print(f"Normal Case Prediction (Expected 1): {model.predict(normal_case)[0]}")
    
    # 2. Teleportation (1000m from geofence)
    teleport_case = np.array([[1000.0, 15.0, 1]])
    print(f"Teleport Case Prediction (Expected -1): {model.predict(teleport_case)[0]}")
    
    # 3. No Photo + Low Accuracy
    bad_case = np.array([[30.0, 150.0, 0]])
    print(f"Bad Case Prediction (Expected -1): {model.predict(bad_case)[0]}")

if __name__ == "__main__":
    train_and_save()
