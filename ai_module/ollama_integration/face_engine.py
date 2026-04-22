import face_recognition
import base64
import numpy as np
from io import BytesIO
from PIL import Image
import requests
import os

def load_image(image_input, max_size=(800, 800)):
    """
    Loads and resizes an image from base64 string, URL, or local path.
    Resizing significantly speeds up face encoding processing.
    """
    if not image_input:
        return None
        
    try:
        raw_img_data = None
        
        # 1. Check if it's a URL
        if str(image_input).startswith('http'):
            response = requests.get(image_input, timeout=10)
            raw_img_data = response.content
            
        # 2. Check if it's base64
        elif ',' in str(image_input) or len(str(image_input)) > 500:
            if ',' in str(image_input):
                image_input = image_input.split(',')[1]
            raw_img_data = base64.b64decode(image_input)
            
        # 3. Assume it's a local file path
        elif os.path.exists(str(image_input)):
            with open(image_input, 'rb') as f:
                raw_img_data = f.read()

        if raw_img_data:
            # Resize image using PIL before passing to face_recognition
            img_pil = Image.open(BytesIO(raw_img_data))
            
            # Convert to RGB if necessary (e.g. RGBA or Grayscale)
            if img_pil.mode != 'RGB':
                img_pil = img_pil.convert('RGB')
                
            img_pil.thumbnail(max_size, Image.Resampling.LANCZOS)
            
            # Convert back to numpy array for face_recognition
            return np.array(img_pil)
                
    except Exception as e:
        print(f"[FACE ENGINE ERROR] Failed to load/resize image: {e}")
        
    return None

def verify_faces(attendance_img_input, profile_img_input):
    """
    Compares two faces and returns similarity score and match result.
    Similarity is calculated as (1 - distance). 
    Higher score = better match.
    """
    try:
        # Load images
        attendance_img = load_image(attendance_img_input)
        profile_img = load_image(profile_img_input)
        
        if attendance_img is None or profile_img is None:
            return {"success": False, "error": "One or both images could not be loaded"}

        # Get encodings
        attendance_encodings = face_recognition.face_encodings(attendance_img)
        profile_encodings = face_recognition.face_encodings(profile_img)

        if not attendance_encodings:
            return {"success": False, "error": "No face detected in attendance photo"}
        if not profile_encodings:
            return {"success": False, "error": "No face detected in profile photo"}

        # Use the first face found in each image
        attendance_enc = attendance_encodings[0]
        profile_enc = profile_encodings[0]

        # Calculate distance (lower is better, 0.6 is typical threshold)
        face_distance = face_recognition.face_distance([profile_enc], attendance_enc)[0]
        
        # Convert distance to a similarity score (0 to 1)
        # Typically distance <= 0.6 is a match.
        similarity_score = max(0, 1 - face_distance)
        
        # We'll use 0.6 as the strict distance threshold (which is ~0.4 similarity)
        # But we'll return a normalized score where 0.6 distance maps to a readable threshold.
        # Let's just return raw similarity and let the caller decide.
        match = face_distance <= 0.6

        return {
            "success": True,
            "match": bool(match),
            "score": float(similarity_score),
            "distance": float(face_distance)
        }

    except Exception as e:
        return {"success": False, "error": str(e)}
