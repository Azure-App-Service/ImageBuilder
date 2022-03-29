import subprocess
import os

HOME_SITE="/home/site/wwwroot"
DEFAULT_SITE="/opt/defaultsite"
STARTUP_COMMAND_FILE="/opt/startup/startupCommand"
APPSVC_VIRTUAL_ENV="antenv"

# Temp patch. Remove when Kudu script is available.
os.environ["PYTHONPATH"] = HOME_SITE + "/antenv/lib/python3.8/site-packages"

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
def check_django():
    with os.scandir(HOME_SITE) as siteRoot:
        for entry in siteRoot:
            if not entry.name.startswith(APPSVC_VIRTUAL_ENV) and entry.is_dir():
                with os.scandir(HOME_SITE + '/'+ entry.name) as subFolder:
                    for subEntry in subFolder:
                        if subEntry.name == 'wsgi.py' and subEntry.is_file():
                            print ("found django app")
                            return entry.name + '.wsgi'
    return None

## Flask check: If 'application.py' is provided or a .py module is present, identify as Flask.
def check_flask():
   with os.scandir(HOME_SITE) as siteRoot:
       for entry in siteRoot:
           if entry.is_file():
               if (entry.name == 'application.py'):
                   print("found flask app")
                   return "application:app"
               else:
                   if (entry.name == 'app.py'):
                       print("found flask app")
                       return "app:app"

   return None

def start_server():
    
    cmd = custom_check()
    if cmd is not None:
        print('custom startup found: ' + cmd);
        subprocess_cmd('. antenv/bin/activate')
        if 'python' in cmd:
            subprocess_cmd(cmd)

        elif 'gunicorn' in cmd:
            subprocess_cmd(cmd)

        else:
            subprocess_cmd(
                'GUNICORN_CMD_ARGS="--bind=0.0.0.0 --timeout 600" gunicorn ' + cmd
               )
        return

    cmd = check_django()
    if cmd is not None:
        subprocess_cmd('. antenv/bin/activate')
        subprocess_cmd(
                'GUNICORN_CMD_ARGS="--bind=0.0.0.0 --timeout 600" gunicorn ' + cmd
               )
        return

    cmd = check_flask()
    if cmd is not None:
        subprocess_cmd('. antenv/bin/activate')
        subprocess_cmd(
                'GUNICORN_CMD_ARGS="--bind=0.0.0.0 --timeout 600" gunicorn ' + cmd
               )
        return

    else:          
        print('starting default app')
        subprocess_cmd(
              'GUNICORN_CMD_ARGS="--bind=0.0.0.0 --chdir /opt/defaultsite" gunicorn application:app'
              )
        return

subprocess_cmd('python --version')
subprocess_cmd('pip --version')
start_server()
