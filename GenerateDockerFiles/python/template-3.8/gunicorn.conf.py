import constants
import code_profiler_installer as cpi
from pathlib import Path
import logging
import logging.handlers
import threading
import socket
import os
import multiprocessing as mp
import ctypes

try :
    appService_server_address = "/tmp/appserviceapplogs_" + os.environ["WEBSITE_ROLE_INSTANCE_ID"]
except :
    appService_server_address = "/tmp/appserviceapplogs_0"
appService_connections_set = set()
appService_connections_set_mutex = threading.Lock()

appService_logs_queue = mp.Queue()
appService_logs_flag = mp.Value(ctypes.c_bool, False)

class appService_customQueueHandler(logging.handlers.QueueHandler) :

    def __init__(self, queue, flag):
        logging.handlers.QueueHandler.__init__(self, queue)
        self.flag = flag

    def emit(self, record):
        if(self.flag.value) :
            try:
                self.enqueue(self.prepare(record))
            except Exception:
                self.handleError(record)


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

    root_logger = logging.getLogger()
    handler = appService_customQueueHandler(appService_logs_queue, appService_logs_flag)
    formatter = logging.Formatter("{ 'time' : '%(asctime)s', 'level': '%(levelname)s', 'message' : '%(message)s', 'pid' : '%(process)d' }")
    handler.setLevel(logging.INFO)
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)

    logsServer = threading.Thread(target=LogsServer)
    logsServer.daemon = True
    logsServer.start()

    logsCollector = threading.Thread(target=LogsCollector)
    logsCollector.daemon = True
    logsCollector.start()

def LogsServer() :
    global appService_connections_set
    global appService_connections_set_mutex

    try :
        os.unlink(appService_server_address)
    except :
        pass

    try :
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(appService_server_address)
        sock.listen()
    except Exception as e:
        print(e)
        return

    while True :

        connection, client_address = sock.accept()
        with appService_connections_set_mutex :
            appService_connections_set.add(connection)
            appService_logs_flag.value = True

def LogsCollector() :
     global appService_connections_set
     global appService_connections_set_mutex

     while True :
         connections = set()
         bad_connections = set()

         with appService_connections_set_mutex :
             connections = appService_connections_set.copy()
             if(len(connections) == 0 and appService_logs_flag.value) :
                 appService_logs_flag.value = False

         log = appService_logs_queue.get(True)

         for conn in connections :
             try :
                 conn.sendall((str(log.getMessage())+"\n").encode())
             except :
                 bad_connections.add(conn)

         with appService_connections_set_mutex :
             appService_connections_set = appService_connections_set.difference(bad_connections)
