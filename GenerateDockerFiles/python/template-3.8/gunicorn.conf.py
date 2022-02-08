import constants
import code_profiler_installer as cpi
from pathlib import Path
import threading
import appServiceAppLogs as asal

try:
    Path(constants.CODE_PROFILER_LOGS_DIR).mkdir(parents=True, exist_ok=True)
    pidfile = constants.PID_FILE_LOCATION
    
except Exception as e:
    print(f"Gunicorn was unable to set the pidfile path due to the exception : {e}")

def post_worker_init(worker):
    try:
        profiler_installer = cpi.CodeProfilerInstaller()
        profiler_installer.add_signal_handlers()              
            
    except Exception as e:
        print(e)

def on_starting(server):

    asal.initAppLogs()
