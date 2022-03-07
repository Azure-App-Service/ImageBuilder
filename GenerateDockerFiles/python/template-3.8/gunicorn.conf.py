import os

# appsvc_profiler is currenly installed from appsvc_code_profiler-1.0.0-py3-none-any.whl
from appsvc_profiler import CodeProfilerInstaller
from appsvc_profiler.constants import CodeProfilerConstants
from pathlib import Path
import appServiceAppLogs as asal

try:
    constants = CodeProfilerConstants()
    Path(constants.CODE_PROFILER_LOGS_DIR).mkdir(parents=True, exist_ok=True)
    pidfile = constants.PID_FILE_LOCATION
    
except Exception as e:
    print(f"Gunicorn was unable to set the pidfile path due to the exception : {e}")

def post_worker_init(worker):
    asal.startHandlerRegisterer()
    
    try:
        cpi = CodeProfilerInstaller()
        cpi.install()              
            
    except Exception as e:
        print(e)

def on_starting(server):
    asal.initAppLogs()