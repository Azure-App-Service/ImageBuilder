import logging
import logging.handlers
import threading
import socket
import os
import sys
import multiprocessing as mp
import appServiceAppLogsConstants as constants


class CustomQueueHandler(logging.Handler):
    def __init__(self, queue):
        logging.Handler.__init__(self)
        self.queue = queue

    def emit(self, record):
        try:
            self.queue.put_nowait(self.format(record))
        except Exception:
            self.handleError(record)


class AppLogsVariables:
    '''A class to store all the variables required by the AppServiceAppLogging infrastructure'''

    def __init__(self):
        self.LOG_LEVEL = logging.DEBUG
        try:
            self.server_address = "/tmp/appserviceapplogs_" + \
                os.environ["WEBSITE_ROLE_INSTANCE_ID"]
        except:
            self.server_address = "/tmp/appserviceapplogs_0"

        self.connections_set = set()
        self.connections_set_mutex = threading.Lock()

        self.logs_queue = mp.Queue()
        self.eventStartLogging = mp.Event()
        self.eventStopLogging = mp.Event()

        self.logger = logging.getLogger(__name__)
        self.initial_log_level = self.logger.level
        self.logger.setLevel(self.LOG_LEVEL)
        logFormatter = logging.Formatter(
            "%(asctime)s  [%(threadName)-10.10s] [%(levelname)-5.5s] : %(message)s")
        try:
            if(not os.path.isdir(constants.APP_LOGGER_LOGS_DIR)):
                os.makedirs(constants.APP_LOGGER_LOGS_DIR)
            try:
                fh = logging.FileHandler(constants.APP_LOGGER_LOG_FILE.format(
                    constants.APP_LOGGER_LOGS_DIR, os.environ["WEBSITE_ROLE_INSTANCE_ID"]))
            except:
                fh = logging.FileHandler(constants.APP_LOGGER_LOG_FILE.format(
                    constants.APP_LOGGER_LOGS_DIR, '0'))
        except:
            fh = logging.StreamHandler(sys.stdout)
        fh.setFormatter(logFormatter)
        self.logger.addHandler(fh)


def initAppLogs():
    '''Initialize the AppServiceAppLogs'''
    global appService_appLogsVars

    appLogSwitch = os.environ.get(constants.APP_SETTING_TO_ENABLE_APP_LOGS)
    if(appLogSwitch is not None and appLogSwitch.lower() == 'false'):
        return

    appService_appLogsVars = AppLogsVariables()

    appService_appLogsVars.logger.debug("Initializating AppServiceAppLogging ")

    logServer = threading.Thread(target=logsServer)
    logServer.daemon = True
    logServer.start()

    logCollector = threading.Thread(target=logsCollector)
    logCollector.daemon = True
    logCollector.start()

    appService_appLogsVars.logger.debug("Initialized AppServiceAppLogging")


def workerLogHandlerRegisterer():
    '''Wait for Logging Start and Stop logging events, and accordingly register and remove logging handler.'''
    global appService_appLogsVars
    while True:
        appService_appLogsVars.logger.debug(
            "Waiting for the logs flag to be set")
        appService_appLogsVars.eventStartLogging.wait()

        root_logger = logging.getLogger()
        handler = CustomQueueHandler(appService_appLogsVars.logs_queue)
        formatter = logging.Formatter(
            "{ 'time' : '%(asctime)s', 'level': '%(levelname)s', 'message' : '%(message)s', 'pid' : '%(process)d' }")
        handler.setLevel(logging.INFO)
        handler.setFormatter(formatter)
        root_logger.addHandler(handler)

        appService_appLogsVars.logger.debug(
            "Registered AppServiceAppLogs handler")
        appService_appLogsVars.eventStopLogging.wait()

        root_logger.removeHandler(handler)
        appService_appLogsVars.logger.debug(
            "Removed AppServiceAppLogs handler")


def startHandlerRegisterer():
    '''Start the LogHandlerRegisterer as a saperate thread'''
    t = threading.Thread(target=workerLogHandlerRegisterer)
    t.deamon = True
    t.start()


def startLogging():
    '''Set flags to start logging'''
    global appService_appLogsVars
    appService_appLogsVars.logger.debug("Starting logging")
    appService_appLogsVars.eventStopLogging.clear()
    appService_appLogsVars.eventStartLogging.set()


def stopLogging():
    '''Set flags to stop logging'''
    global appService_appLogsVars
    appService_appLogsVars.logger.debug("Stopping logging")
    appService_appLogsVars.eventStartLogging.clear()
    appService_appLogsVars.eventStopLogging.set()


def logsServer():
    '''Listen for connections which and start logging accordingly.'''
    global appService_appLogsVars

    try:
        os.unlink(appService_appLogsVars.server_address)
    except:
        appService_appLogsVars.logger.debug(
            "Did not find any previously bound socket")

    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(appService_appLogsVars.server_address)
        sock.listen(1)
    except Exception as e:
        appService_appLogsVars.logger.error(
            "Error while trying to bind to socket : " + str(e))
        return

    try:
        while True:
            connection, client_address = sock.accept()
            appService_appLogsVars.logger.debug("Received Logs Request")
            with appService_appLogsVars.connections_set_mutex:
                appService_appLogsVars.connections_set.add(connection)
                startLogging()
    except Exception as e:
        appService_appLogsVars.logger.error(
            "Exception while trying to accept connections : " + str(e))

    appService_appLogsVars.logger.debug("Log server exiting")


def logsCollector():
    '''Check for active connections and send logs to those connections. Also stop logging in case of no active connections.'''
    global appService_appLogsVars
    try:
        while True:
            log = appService_appLogsVars.logs_queue.get(True)
            connections = set()
            bad_connections = set()

            with appService_appLogsVars.connections_set_mutex:
                connections = appService_appLogsVars.connections_set.copy()
                if(len(connections) == 0 and appService_appLogsVars.eventStartLogging.is_set()):
                    stopLogging()
                    continue

            for conn in connections:
                try:
                    conn.sendall((log+"\n").encode())
                    appService_appLogsVars.logger.debug("Sent logs")
                except:
                    bad_connections.add(conn)

            with appService_appLogsVars.connections_set_mutex:
                appService_appLogsVars.connections_set = appService_appLogsVars.connections_set.difference(
                    bad_connections)

    except Exception as e:
        appService_appLogsVars.logger.error(
            "Exception when getting logs from queue : " + str(e))

    appService_appLogsVars.logger.debug("logs Collector exiting")
