import os
import sys

from pip._vendor.distlib import scripts

specs = 'nova = novaclient.shell:main' 

scripts_path = os.path.join(os.path.dirname(sys.executable), 'Scripts')
m = scripts.ScriptMaker(None, scripts_path)
m.executable = sys.executable
m.make(specs)

