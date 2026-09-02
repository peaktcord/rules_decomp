"""Fixture for script_check: succeed only when given the expected argument."""
import os
import sys

if sys.argv[1:] != ["--expect", "fixture"]:
    print("unexpected arguments: %r" % sys.argv[1:])
    sys.exit(1)
if os.environ.get("CHECK_FIXTURE") != "set":
    print("environment variable not forwarded")
    sys.exit(1)
print("check fixture ok")
