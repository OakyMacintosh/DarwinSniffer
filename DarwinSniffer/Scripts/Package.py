#
#  Package.py
#  DarwinSniffer
#
#  Created by Oaky on 04/02/26.
#

from macos_pkg_builder import Packages

pkg_obj = Packages(
    pkg_output="DarwinSniffer.pkg",
    pkg_bundle_id="dev.github.oaky.darwinsniffer",
    pkg_file_structure={
        "./Build/DarwinSniffer": "/usr/local/bin/sniffme"
    },
    pkg_title="DarwinSniffer",
    pkg_as_distribution=True
)

assert pkg_obj.build() is True
