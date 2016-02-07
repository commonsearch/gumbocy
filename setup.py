from distutils.core import setup
from distutils.extension import Extension

# Use "make cythonize" to build the c file from the .pyx source
ext_modules = [
    Extension("gumbocy",
              ["gumbocy.c"],
              libraries=["gumbo"])
]

setup(
  name="gumbocy",
  version="0.1",
  description="Python binding for gumbo-parser using Cython",
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
    'Development Status :: 3 - Alpha',
    # 'Development Status :: 4 - Beta',
    # 'Development Status :: 5 - Production/Stable',
    # 'Development Status :: 6 - Mature',
    # 'Development Status :: 7 - Inactive',
    "Environment :: Other Environment",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: Apache Software License",
    "Operating System :: OS Independent",
    "Topic :: Software Development :: Libraries"
  ]
)
