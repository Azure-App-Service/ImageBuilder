import constants
import signal

class SignalHelper():

    def can_usr_signals_be_used(self):
        is_sigusr1_available = self._is_signal_usr_signal_handlers_used(signal.SIGUSR1)
        is_sigusr2_available = self._is_signal_usr_signal_handlers_used(signal.SIGUSR2)
        return is_sigusr1_available and is_sigusr2_available

    def _is_signal_usr_signal_handlers_used(self, signal_to_test):
        signal_handler = signal.getsignal(signal_to_test)
        status = (signal_handler is None
                  or self._is_default_signal_handler(signal_handler)
                  or self._is_ignore_signal_handler(signal_handler)
                  or self._is_gunicorn_logfile_signal_handler(signal_handler) )
                  # Gunicorn is configured to emit logs to std. Hence
                  # we can safely override SIGUSR1 handler

        return status

    def _is_default_signal_handler(self, signal_handler):
        return (signal_handler is not None
                and hasattr(signal_handler , "name")
                and signal_handler.name == signal.SIG_DFL.name)

    def _is_ignore_signal_handler(self, signal_handler):
        return (signal_handler is not None
                and hasattr(signal_handler , "name")
                and signal_handler.name == signal.SIG_IGN.name)

    def _is_gunicorn_logfile_signal_handler(self, signal_handler):
        return (signal_handler is not None
                and constants.GUNICORN_LOGFILE_SIGNAL_HANDLER_INFO in str(signal_handler))