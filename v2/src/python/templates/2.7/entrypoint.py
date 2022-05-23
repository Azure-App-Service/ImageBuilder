import subprocess
import os
import scandir

HOME_SITE="/home/site/wwwroot"
DEFAULT_SITE="/opt/defaultsite"
STARTUP_COMMAND_FILE="/opt/startup/startupCommand"
APPSVC_VIRTUAL_ENV="antenv"

# Temp patch. Remove when Kudu script is available.
os.environ["PYTHONPATH"] = HOME_SITE + "/antenv2.7/lib/python2.7/site-packages"

def subprocess_cmd(command):
    print ('executing:')
    print (command)

    process = subprocess.Popen(command,stdout=subprocess.PIPE, shell=True)
    proc_stdout = process.communicate()[0].strip()
    print (proc_stdout.decode("utf-8"))

## Check for custom startup command
def custom_check():
    with open(STARTUP_COMMAND_FILE, 'r') as myfile:
          startupScript = myfile.read().rstrip()
          if not startupScript:
              return None
          else:
              if ".." not in startupScript:
                  startupFilePath = HOME_SITE + '/' + startupScript
                  print('startup script: ' + startupFilePath)
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
              else:
                  print('invalid data in startup script, ignoring it.')
                  return None
                
              return startupScript

## Django check: If 'wsgi.py' is provided, identify as Django. 
## Django check: If 'wsgi.py' is provided, identify as Django.
def check_django():
    print("Checking for django app in site's content folder:")

    try:
        siteRoot = scandir.scandir(HOME_SITE)
        for entry in siteRoot:
            if not entry.name.startswith(APPSVC_VIRTUAL_ENV) and entry.is_dir():
                print("Detected directory: '" + entry.name + "'")
                subFolder = scandir.scandir(HOME_SITE + '/'+ entry.name)
                for subEntry in subFolder:
                    if subEntry.name == 'wsgi.py' and subEntry.is_file():
                        print("Found wsgi.py in directory '" + entry.name +  "', django app detection success")
                        return entry.name + '.wsgi'
    finally:
        print("django test returned ")

## Flask check: If 'application.py' is provided or a .py module is present, identify as Flask.
def check_flask():
    print("Checking for flask app in site's content folder:")

    try:
        siteRoot = scandir.scandir(HOME_SITE)
        for entry in siteRoot:
            if entry.is_file() and (entry.name == "application.py" or entry.name == "app.py"):
                print("found app '" + entry.name + "' in root folder, flask app detection success")
                return entry.name[:-3] + ":app"

        return None
    finally:
        print("flask test returned")


def start_server():
    cmd = custom_check()
    if cmd is not None:
        print('custom startup found: ' + cmd);
        subprocess_cmd('. antenv2.7/bin/activate')
        if 'python' in cmd:
            subprocess_cmd(cmd)

        elif 'gunicorn' in cmd:
            subprocess_cmd(cmd)

        else:
            subprocess_cmd(
                'gunicorn --bind=0.0.0.0 --timeout 600 ' + cmd
               )

    cmd = check_django()
    if cmd is not None:
        print(cmd)
        subprocess_cmd('. antenv2.7/bin/activate')
        subprocess_cmd(
                'gunicorn --bind=0.0.0.0 --timeout 600 ' + cmd
               )

    cmd = check_flask()
    if cmd is not None:
        print(cmd)
        subprocess_cmd('. antenv2.7/bin/activate')
        subprocess_cmd(
                'gunicorn --bind=0.0.0.0 --timeout 600 ' + cmd
               )
    else:          
        print('starting default app')
        subprocess_cmd(
                'gunicorn --bind=0.0.0.0 --timeout 600 --chdir /opt/defaultsite application:app'
              )

subprocess_cmd('python --version')
subprocess_cmd('pip --version')
start_server()
