import subprocess
import os

HOME_SITE="/home/site/wwwroot"
DEFAULT_SITE="/opt/defaultsite"
STARTUP_COMMAND_FILE="/opt/startup/startupCommand"
APPSVC_VIRTUAL_ENV="antenv"

def subprocess_cmd(command):
    print ('executing:')
    print (command)

    process = subprocess.Popen(command,stdout=subprocess.PIPE, shell=True)
    proc_stdout = process.communicate()[0].strip()
    print (proc_stdout.decode("utf-8"))

def getStartupArgs():
    with open(STARTUP_COMMAND_FILE, 'r') as myfile:
        startupScript = myfile.read().rstrip()
        if not startupScript:
            print('App startup command not specified, will use defaults..')
            return None
        else:
            if ".." not in startupScript:
                startupFilePath = HOME_SITE + '/' + startupScript
                print('checking for startup script file: ' + startupFilePath)
                try:
                    startupFile = open(startupFilePath, 'r')
                    print ('identified startup script as a file on disk')
                    startArgs = startupFile.read()
                    print(startArgs)
                    if not startArgs:
                        return None
                    else:
                        return startArgs

                except:
                    # appCommandLine is not a file, assume it is the script to be started bu gunicorn
                    print('startup script is not a file, use it as gunicorn arg')
                    return startupScript

def find_and_launch_entrypoint():
    if os.path.isdir(HOME_SITE + '/antenv'):
        print('Executing entrypoint.py script:')
        subprocess_cmd('python -u /usr/local/bin/entrypoint.py')
    else:
        oryxCmd = "oryx create-script -appPath /home/site/wwwroot -output /opt/startup/startup.sh -defaultApp /opt/defaultsite "
        cmd = getStartupArgs()
        if cmd is not None:
            oryxCmd += ' -userStartupCommand ' + '\'' + cmd + '\''

        print('Generating startup command with oryxCmd ' + oryxCmd)
        subprocess_cmd(oryxCmd)
        print('Launching oryx-Startup script ')
        subprocess_cmd('chmod +x /opt/startup/startup.sh')
        subprocess_cmd('/opt/startup/startup.sh')

subprocess_cmd('python --version')
find_and_launch_entrypoint()