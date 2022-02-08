import threading
import appServiceAppLogs as asal

def on_starting(server):

    asal.initAppLogs()
    
def post_worker_init(worker):
    
    asal.workerLogHandlerRegisterer()