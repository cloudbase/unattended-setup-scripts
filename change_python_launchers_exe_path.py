import os
import sys
import win32api

from pip._vendor.distlib import scripts

specs = 'nova = novaclient.shell:main' 

scripts_path = os.path.join(os.path.dirname(sys.executable), 'Scripts')
m = scripts.ScriptMaker(None, scripts_path)
m.executable = win32api.GetShortPathName(sys.executable)
m.make(specs)

