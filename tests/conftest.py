import os
import sys

parent = os.path.realpath(os.path.dirname(__file__) + "/..")
SOURCES_ROOT = os.path.realpath(parent + "/src")
if os.path.isdir(SOURCES_ROOT) and SOURCES_ROOT not in sys.path:
    sys.path.insert(0, SOURCES_ROOT)

if str(parent) not in sys.path:
    sys.path.insert(0, str(parent))
