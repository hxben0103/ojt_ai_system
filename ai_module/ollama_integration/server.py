from flask import Flask, request, jsonify
from flask_cors import CORS
from chatbot_handler import chatbot_response

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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
