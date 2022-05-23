start-viztracer-profiler(){
    if [ $# -eq 0 ];
    then 
        echo "usage : code-profiler --attach <PID> -t <Number of seconds to profile>"
        echo ""
    else
        echo "Starting the code profiler."
        viztracer $@
        echo ""
        vizviewer
        echo ""
    fi
}

enable-code-profiler-helper-message(){
    echo "To enable code profiler, add the App Setting WEBSITE_ENABLE_DEFAULT_CODE_PROFILER=true"
    echo "NOTE : Adding this App Setting will restart your App Service !!"
    echo ""
}

code-profiler(){
    shouldEnableCodeProfiler="${APPSETTING_WEBSITE_ENABLE_DEFAULT_CODE_PROFILER:- 'false'}"
    signalHandlersNotInitialized="${CODE_PROFILER_SIGNAL_HANDLER_NOT_INITIALIZED:- 'true'}"
    if [[ ! -v APPSETTING_WEBSITE_ENABLE_DEFAULT_CODE_PROFILER ]];
    then
        enable-code-profiler-helper-message

    elif [[ $shouldEnableCodeProfiler == "false" ]];
    then
        echo "Code Profiler is currently disabled through App Setting"
        enable-code-profiler-helper-message

    elif [[ $signalHandlersNotInitialized == "true" ]];
    then
        echo "There was an issue while installing code profiler."
        echo "Please review installation log in /home/LogFiles/CodeProfiler"        

    else
        start-viztracer-profiler $@
    fi
}
