# gumbocy

**gumbocy** is an alternative Python binding for the excellent [Gumbo](https://github.com/google/gumbo-parser) HTML5 parser, originally written for [Common Search](http://about.commonsearch.org).

It differs from the [official Python binding](https://github.com/google/gumbo-parser/tree/master/python/gumbo) in a few ways:

 - It is optimized for performance by using [Cython](http://cython.org/).
 - It has a smaller feature set and doesn't aim to be a general-purpose binding.
 - Its `listnodes()` API just returns nodes as a flat list of tuples.
 - It is generally restrictive: attributes have to be whitelisted.

## Installation

The only dependency is [Gumbo](https://github.com/google/gumbo-parser), which should be installed prior to anything else.

### From PyPI

```
pip install gumbocy
```

### From source

Clone this repository, then:

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

parser = gumbocy.HTMLParser("""<html><head><title>Hello</title></head><body>world!</body></html>""")
parser.parse()
print parser.listnodes(options={})

=> [(0, "html"), (1, "head"), (2, "title"), (3, None, "Hello"), (1, "body"), (2, None, "world!")]
```

For more examples, see the tests.

## Options reference

 - **attributes_whitelist**: a set of attributes which, if present, will be returned in a dict as the 3rd element of a node tuple. Note that "class" is returned as a frozenset. Defaults to `set()`.
 - **nesting_limit**: an integer to specify the maximum nesting level that will be returned. Defaults to `999`.
 - **head_only**: a boolean that will make gumbocy return only the elements in the <head> of the document. Useful for parsing only <meta> tags for instance. Defaults to `False`.
 - **tags_ignore**: a list of tag names that won't be returned (as well as their children).
 - **ids_ignore**: a list of IDs for which matching elements (and their children) won't be returned. "id" needs to be in `attributes_whitelist` for this to work.
 - **classes_ignore**: a list of classes for which matching elements (and their children) won't be returned. "class" needs to be in `attributes_whitelist` for this to work.


## Contributing

If you are using Sublime Text, we recommend installing [Cython support](https://github.com/NotSqrt/sublime-cython).

All contributions are welcome! Feel free to use the Issues tab or send us your Pull Requests.

## Changelog

### 0.1: Initial public release