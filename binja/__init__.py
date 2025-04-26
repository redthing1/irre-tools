# IRRE/__init__.py
# this file registers the architecture and binary view with binary ninja.

from binaryninja import log_info

# import the architecture and view classes
# use "." for relative imports within the plugin package
from .arch_irre import IRRE
from .view_rega import REGAView

# register the architecture plugin
IRRE.register()
# register the binary view plugin
REGAView.register()

log_info("irre architecture and rega binaryview plugins loaded.")
