import logging
import logging.handlers
import threading
import socket
import os
import ctypes
import multiprocessing as mp

class CustomQueueHandler(logging.Handler) :
    
    def __init__(self, queue, flag):
        logging.Handler.__init__(self)
        self.queue = queue
        self.flag = flag
    
    def emit(self, record):
        if(self.flag.value) :
            try:
                self.queue.put_nowait(self.format(record))
            except Exception:
                self.handleError(record)

class AppLogsVariables :
    
    def __init__(self) :

        try :
            self.server_address = "/tmp/appserviceapplogs_" + os.environ["WEBSITE_ROLE_INSTANCE_ID"]
        except :
            self.server_address = "/tmp/appserviceapplogs_0"
    
        self.connections_set = set()
        self.connections_set_mutex = threading.Lock()

        self.logs_queue = mp.Queue()
        self.logs_flag = mp.Value(ctypes.c_bool, False)

def initVariables() :

    global appService_appLogsVars

    appService_appLogsVars = AppLogsVariables()

def registerLogHandler() :

    global appService_appLogsVars

    root_logger = logging.getLogger()
    handler = CustomQueueHandler(appService_appLogsVars.logs_queue, appService_appLogsVars.logs_flag)
    formatter = logging.Formatter("{ 'time' : '%(asctime)s', 'level': '%(levelname)s', 'message' : '%(message)s', 'pid' : '%(process)d' }")
    handler.setLevel(logging.INFO)
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)

def logsServer() :

    global appService_appLogsVars

    try :
        os.unlink(appService_appLogsVars.server_address)
    except :
        pass

    try :
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(appService_appLogsVars.server_address)
        sock.listen(1)
    except Exception as e:
        print(e)
        return

    while True :

        connection, client_address = sock.accept()
        with appService_appLogsVars.connections_set_mutex :
            appService_appLogsVars.connections_set.add(connection)
            appService_appLogsVars.logs_flag.value = True

def logsCollector() :

     global appService_appLogsVars

     while True :
         connections = set()
         bad_connections = set()

         with appService_appLogsVars.connections_set_mutex :
             connections = appService_appLogsVars.connections_set.copy()
             if(len(connections) == 0 and appService_appLogsVars.logs_flag.value) :
                 appService_appLogsVars.logs_flag.value = False

         log = appService_appLogsVars.logs_queue.get(True)

         for conn in connections :
             try :
                 conn.sendall((log+"\n").encode())
             except :
                 bad_connections.add(conn)

         with appService_appLogsVars.connections_set_mutex :
             appService_appLogsVars.connections_set = appService_appLogsVars.connections_set.difference(bad_connections)
