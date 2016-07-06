from distutils.core import setup
from distutils.extension import Extension
import os

# gumbocy.c will be present when installing from the source distribution on PyPI
if os.path.isfile("gumbocy.cpp"):

  # Use "make cythonize" to build the c file from the .pyx source
  ext_modules = [
      Extension("gumbocy",
                ["gumbocy.cpp"],
                libraries=["gumbo"],
                language="c++",
                extra_compile_args=["-std=c++11", '-O3', '-static-libstdc++'],
                extra_link_args=["-std=c++11"])  # , "-static"

  ]

else:
  raise Exception("Must run 'make cythonize' first!")

# # If the .c file is missing, we must be in local or installing from GitHub.
# # In this case, we need Cython to be already installed.
# else:
#   from Cython.Build import cythonize

#   ext_modules = cythonize([
#       Extension("gumbocy",
#                 ["gumbocy.pyx"],
#                 libraries=["gumbo"],
#                 language="c++",
#                 extra_compile_args=["-std=c++11"],
#                 extra_link_args=["-std=c++11"])
#   ])


setup(
  name="gumbocy",
  version="0.1",
  description="Python binding for gumbo-parser (an HTML5-compliant parser) using Cython",
  author="Common Search contributors",
  license="Apache License, Version 2.0",
  url="https://github.com/commonsearch/gumbocy",
  ext_modules=ext_modules,
  keywords=["gumbo", "gumbo-parser", "gumbo-cython", "gumbocy", "cython", "htmlparser", "html5", "html5lib"],
  classifiers=[
    "Programming Language :: Python",
    "Programming Language :: Python :: 2.7",
    # 'Development Status :: 1 - Planning',
    # 'Development Status :: 2 - Pre-Alpha',
    # 'Development Status :: 3 - Alpha',
    'Development Status :: 4 - Beta',
    # 'Development Status :: 5 - Production/Stable',
    # 'Development Status :: 6 - Mature',
    # 'Development Status :: 7 - Inactive',
    "Programming Language :: Python :: Implementation :: CPython",
    "Programming Language :: Python :: Implementation :: PyPy",
    "Environment :: Other Environment",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: Apache Software License",
    "Operating System :: OS Independent",
    "Topic :: Software Development :: Libraries"
  ]
)
