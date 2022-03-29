import appServiceAppLogs as asal

# appsvc_profiler is currenly installed from appsvc_code_profiler-1.0.0-py3-none-any.whl
from appsvc_profiler import CodeProfilerInstaller

def post_worker_init(worker):
    asal.startHandlerRegisterer()
    
    try:
        cpi = CodeProfilerInstaller()
        cpi.install()              
            
    except Exception as e:
        print(e)

def on_starting(server):
    asal.initAppLogs()
