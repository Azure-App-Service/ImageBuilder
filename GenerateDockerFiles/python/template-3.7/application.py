from flask import Flask
import os
app = Flask(__name__, static_folder='/opt/defaultsite')

@app.route('/')
def root():
    if os.path.isdir('/home/site/deployments') and len(next(os.walk('/home/site/deployments'))[1]) > 1:
        return app.send_static_file('hostingstart_dep.html')
    else:
        return app.send_static_file('hostingstart.html')
