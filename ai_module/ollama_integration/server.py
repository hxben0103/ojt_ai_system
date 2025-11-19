from flask import Flask, request, jsonify
from flask_cors import CORS
from chatbot_handler import chatbot_response
from insight_engine import predict_performance, build_features_from_snapshot

app = Flask(__name__)
CORS(app)  # ✅ Enables communication with Flutter (web or mobile)

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.get_json()
        user_message = data.get("message", "")
        if not user_message:
            return jsonify({"response": "Please enter a message."})
        bot_reply = chatbot_response(user_message)
        return jsonify({"response": bot_reply})
    except Exception as e:
        return jsonify({"response": f"⚠️ Error: {str(e)}"})

@app.route('/predict', methods=['POST'])
def predict():
    """
    Daily risk prediction endpoint.
    Accepts a daily snapshot of student performance and returns AI prediction.
    """
    try:
        data = request.get_json() or {}
        
        # Build features from snapshot
        features = build_features_from_snapshot(data)
        
        # Get prediction
        result = predict_performance(features)
        
        return jsonify({
            "features_used": features,
            "prediction": result
        })
    except ValueError as e:
        return jsonify({
            "error": str(e),
            "message": "Model not loaded or invalid input"
        }), 400
    except Exception as e:
        return jsonify({
            "error": str(e),
            "message": "Prediction failed"
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
