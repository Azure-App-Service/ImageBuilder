import constants
import logging
import os
from pathlib import Path
from signal_helper import SignalHelper

LOG_LEVEL = logging.DEBUG
class CodeProfilerInstaller:    
    def __init__(self):
        self.signal_helper = SignalHelper()
        self.is_profiler_enabled = False
        self._ensure_logs_dir_is_created()
        self.logger = self._initialize_logger()
        self.initial_log_level = self.logger.level
        self.logger.setLevel(LOG_LEVEL)
        self.logger.debug("Code Profiler Installer is starting up")  
        self.logger.debug(f"The logger has initial logger level as {logging.getLevelName(self.initial_log_level)} " \
                          f"and was updated to {logging.getLevelName(LOG_LEVEL)}")
    
    def _ensure_logs_dir_is_created(self):
        Path(constants.CODE_PROFILER_LOGS_DIR).mkdir(parents=True, exist_ok=True)
        
    def _initialize_logger(self):
        logger = logging.getLogger(__name__)
        logFormatter = logging.Formatter("%(asctime)s  [%(threadName)-10.10s] [%(levelname)-5.5s] : %(message)s")
        fh = logging.FileHandler(constants.CODE_PROFILER_INSTALLER_LOG_FILE)
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(logFormatter)
        logger.addHandler(fh)
        return logger
    
    def add_signal_handlers(self):
        try:
            if self._should_profiler_be_enabled() and self.signal_helper.can_usr_signals_be_used():
                from viztracer import VizTracer 
                tracer = VizTracer(output_file= constants.CODE_PROFILER_TRACE_NAME,
                                   ignore_c_function=True, 
                                   plugins=['vizplugins.cpu_usage','vizplugins.memory_usage'], 
                                   max_stack_depth=20)
                self.logger.info("Attempting to install the default code profiler.")
                tracer.install()
                self.logger.info("Successfully installed code profiler.")
                self._set_signal_handler_not_initialized_env = False
                self.is_profiler_enabled = True
            else:
                self._disable_code_profiler()
                
        except Exception as e:
            self.logger.exception(e)
            self._disable_code_profiler()
            
        finally:
            self.shut_down()
    
    def _should_profiler_be_enabled(self):
        enable_profiler_appsetting_value = os.environ.get(constants.APP_SETTING_TO_ENABLE_CODE_PROFILER)    
        return (enable_profiler_appsetting_value is not None
                and enable_profiler_appsetting_value.lower() == "true")          
        
    def _set_signal_handler_not_initialized_env(status):
        os.environ[constants.CODE_PROFILER_SIGNAL_HANDLER_NOT_INITIALIZED_ENV_NAME] = f"{status}".lower()        
    
    def _disable_code_profiler(self):
        self._set_signal_handler_not_initialized_env = True
        self.logger.info("Code Profiler is disabled. Hence signal handlers cannot be added.")    
    
    def shut_down(self):
        self.logger.debug(f"Setting the logger level back to {logging.getLevelName(self.initial_log_level)}")
        self.logger.debug("Code Profiler Installer is exiting")        
        self.logger.level = self.initial_log_level
    