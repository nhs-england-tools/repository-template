from flask import Flask
from flask_wtf.csrf import CSRFProtect

app = Flask(__name__)
csrf = CSRFProtect()
csrf.init_app(app)

@app.route("/")
def index():
    return "Hello World!"

app.run(host='0.0.0.0', port=8000)
