# gumbocy

[![Build Status](https://travis-ci.org/commonsearch/gumbocy.svg?branch=master)](https://travis-ci.org/commonsearch/gumbocy) [![Apache License 2.0](https://img.shields.io/github/license/commonsearch/gumbocy.svg)](LICENSE)

**gumbocy** is an alternative Python binding for the excellent [Gumbo](https://github.com/google/gumbo-parser) HTML5 parser, originally written for [Common Search](http://about.commonsearch.org).

It differs from the [official Python binding](https://github.com/google/gumbo-parser/tree/master/python/gumbo) in a few ways:

 - It is optimized for performance by using [Cython](http://cython.org/).
 - It has a smaller feature set and doesn't aim to be a general-purpose binding.
 - Its `listnodes()` API just returns nodes as a flat list of tuples.
 - Its `analyze()` API traverses the HTML tree and returns high-level data like groups of words and lists of hyperlinks.
 - It is generally restrictive. For instance, attributes have to be whitelisted.

## Installation

The only dependency is [Gumbo](https://github.com/google/gumbo-parser). You need to install it (possibly with `make gumbo_build`) if you are not using the Docker method below.

### From PyPI

```
pip install gumbocy
```

### From source with Docker

Clone this repository, then:

```
make docker_build
make docker_shell
```

You will end up in a container with Gumbo and Gumbocy already installed.

You can then run the tests for Python 2.7 and PyPy:

```
make docker_test
GUMBOCY_PYTHON_VERSION=pypy make docker_test
```

### From source without Docker

This is an unsupported method.

```
make virtualenv
source venv/bin/activate
make build_ext
```

## Running the tests

```
make test
```

## Quickstart

```
import gumbocy

parser = gumbocy.HTMLParser(options={})
parser.parse("""<html><head><title>Hello</title></head><body>world!</body></html>""")
print parser.listnodes()

=> [(0, "html"), (1, "head"), (2, "title"), (3, None, "Hello"), (1, "body"), (2, None, "world!")]

print parser.analyze()

=> {'word_groups': [('world!', 'body')], 'external_hyperlinks': [], 'internal_hyperlinks': [], 'title': 'Hello'}

```

For more usage examples, see the [tests](https://github.com/commonsearch/gumbocy/blob/master/tests/).

## Options reference

 - **attributes_whitelist**: a set of attributes which, if present, will be returned in a dict as the 3rd element of a node tuple by `listnodes()`. Note that "class" is returned as a frozenset. Defaults to `set()`.
 - **nesting_limit**: an integer to specify the maximum nesting level that will be returned. Defaults to `999`.
 - **head_only**: a boolean that will make gumbocy return only the elements in the <head> of the document. Useful for parsing only <meta> tags for instance. Defaults to `False`.
 - **tags_ignore**: a list of tag names that won't be returned (as well as their children).
 - **ids_ignore**: a list of IDs for which matching elements (and their children) won't be returned.
 - **classes_ignore**: a list of classes for which matching elements (and their children) won't be returned.


## Contributing

If you are using Sublime Text, we recommend installing [Cython support](https://github.com/NotSqrt/sublime-cython).

All contributions are welcome! Feel free to use the [Issues tab](https://github.com/commonsearch/gumbocy/issues) or send us your Pull Requests.

## Changelog

### 0.2
 - New `analyze()` API, moving most of the tree traversal that was happening in `cosr-back` to Cython, resulting in a ~3x speedup in indexing speed.
 - More tests

### 0.1
 - Initial public release
