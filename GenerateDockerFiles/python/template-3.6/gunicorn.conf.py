import threading
import os
import appServiceAppLogs as asal

from pathlib import Path

# For python version > 3.6, the following constants are dervied from appsvc_profiler package.
# Oryx has issues installing viztracer for Python 3.6
# Hence appsvc_profiler which wraps around viztracer cannot be instead. 
INSTANCE_ID_ENV_NAME = "WEBSITE_INSTANCE_ID"
def get_instance_id_trimmed():
    instance_id = os.getenv(INSTANCE_ID_ENV_NAME,"default")
    return instance_id[:6]

CODE_PROFILER_LOGS_DIR = "/home/LogFiles/CodeProfiler"
PID_FILE_LOCATION = f"{CODE_PROFILER_LOGS_DIR}/{get_instance_id_trimmed()}_master_process.pid"

try:
    Path(CODE_PROFILER_LOGS_DIR).mkdir(parents=True, exist_ok=True)
    pidfile = PID_FILE_LOCATION
    
except Exception as e:
    print(f"Gunicorn was unable to set the pidfile path due to the exception : {e}")

def on_starting(server):
    asal.initAppLogs()

def post_worker_init(worker):
    asal.startHandlerRegisterer()
