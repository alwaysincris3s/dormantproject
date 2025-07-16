from flask import Flask, request
import os
import datetime
import subprocess

app = Flask(__name__)
OPT_IN_FILE = "/etc/dormant_opt_in.conf"
DEACTIVATED_LOG = "/var/log/deactivated_accounts.log"  # Define a log for deactivations

@app.route('/confirm')
def confirm():
    user = request.args.get('user')
    response = request.args.get('response')

    if response == "yes":
        now = datetime.datetime.now().strftime("%Y-%m-%d")
        with open(OPT_IN_FILE, "a") as f:
            f.write(f"{user}={now}\n")
        return f"✅ Your account will remain active. Thank you, {user}!"

@app.route('/deactivate/<username>', methods=['GET'])
def deactivate_account(username):
    try:
        # Deactivate the user account
        subprocess.run(['usermod', '-L', username], check=True)
        subprocess.run(['usermod', '-s', '/sbin/nologin', username], check=True)
        # Log the action
        os.makedirs(os.path.dirname(DEACTIVATED_LOG), exist_ok=True)
        with open(DEACTIVATED_LOG, 'a') as f:
            f.write(f"{username} deactivated via email link.\n")

        return f"❌ Your account '{username}' has been deactivated as requested."
    except Exception as e:
        return f"⚠️ Failed to deactivate account '{username}': {e}"

@app.route('/')
def index():
    return "🛡️  Dormant Account Management Flask Server is running."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
