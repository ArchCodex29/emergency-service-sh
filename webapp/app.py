#!/usr/bin/env python3
from flask import Flask, render_template, request
import os
import datetime
import subprocess

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return render_template("index.html")

@app.route("/shutdown", methods=["POST"])
def shutdown():
    try:
        # Call system shutdown
        subprocess.run(["sudo", "shutdown", "-h", "now"], check=True)
        # subprocess.run("shutdown -h 0", shell=True, check=True)
    except Exception as e:
        app.logger.error(f"Shutdown command failed: {e}")
    return "System shutting down..."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9999)
