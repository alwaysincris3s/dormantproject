from flask import Flask, request
import os
import datetime
import subprocess  # ✅ You forgot this!
from pathlib import Path

app = Flask(__name__)
OPT_IN_FILE = "/etc/dormant_opt_in.conf"
DEACTIVATED_LOG = "/var/log/dormant_deactivated.log"

@app.route('/confirm')
def confirm():
    user = request.args.get('user')
    response = request.args.get('response')

    if not user or not response:
        return "⚠️ Missing 'user' or 'response' parameter.", 400

    if response == "yes":
        try:
            now = datetime.datetime.now().strftime("%Y-%m-%d")
            with open(OPT_IN_FILE, "a") as f:
                f.write(f"{user}={now}\n")
            return f"✅ Your account will remain active. Thank you, {user}!"
        except Exception as e:
            return f"⚠️ Failed to save opt-in: {e}", 500

    elif response == "no":
        try:
            subprocess.run(['usermod', '-L', user], check=True)
            subprocess.run(['usermod', '-s', '/sbin/nologin', user], check=True)
            Path(os.path.dirname(DEACTIVATED_LOG)).mkdir(parents=True, exist_ok=True)
            with open(DEACTIVATED_LOG, "a") as f:
                f.write(f"{user} deactivated via email link on {datetime.datetime.now()}\n")
            return f"❌ Your account '{user}' has been deactivated as requested."
        except Exception as e:
            return f"⚠️ Failed to deactivate account '{user}': {e}", 500

    else:
        return f"⚠️ Unknown response: '{response}'", 400

@app.route('/')
def index():
    return "🛡️  Dormant Account Management Flask Server is running."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
