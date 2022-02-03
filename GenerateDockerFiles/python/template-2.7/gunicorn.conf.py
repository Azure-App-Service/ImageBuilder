import threading
import appServiceAppLogs as asal

def on_starting(server):

    asal.initVariables()

    asal.registerLogHandler()

    logsServer = threading.Thread(target=asal.logsServer)
    logsServer.daemon = True
    logsServer.start()

    logsCollector = threading.Thread(target=asal.logsCollector)
    logsCollector.daemon = True
    logsCollector.start()
