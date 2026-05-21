from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return "<h1>Hola Mundo DevOps — API</h1><p>Endpoint disponible: <code>/health</code></p>"


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "dummy-b", "version": "1.0.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
