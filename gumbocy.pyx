import re
cimport gumbocy


cdef extern from "stdio.h":
    int printf(const char* format, ...);


_RE_SPLIT_WHITESPACE = re.compile(r"\s+")


cdef class HTMLParser:

    cdef char* html
    cdef gumbocy.GumboOutput* output
    cdef int nesting_limit
    cdef list nodes

    # TODO: continue transforming this into proper C objects for further speedups in _iternode()
    # See gumbocy.html
    cdef dict options

    def __cinit__(self, char* html):
        self.html = html
        
    cdef bint _traverse_node(self, int level, gumbocy.GumboNode* node):
        """ Traverses the node tree. Return 1 to stop at this level """

        if level > self.nesting_limit:
            return 0

        if node.type == gumbocy.GUMBO_NODE_TEXT:
            self.nodes.append((level, None, node.v.text.text))

        elif node.type == gumbocy.GUMBO_NODE_ELEMENT:

            tag_name = gumbocy.gumbo_normalized_tagname(node.v.element.tag)

            if self.options.get("head_only") and tag_name in (b"body", b"span", b"div", b"p"):
                return 1

            if tag_name in self.options.get("tags_ignore", []):
                return 0

            if self.options.get("attributes_whitelist"):

                # Build a dict with all the whitelisted attributes
                attrs = {}
                for i in range(node.v.element.attributes.length):
                    attr = <gumbocy.GumboAttribute *> node.v.element.attributes.data[i]
                    if attr.name in self.options["attributes_whitelist"]:
                        if attr.name == b"class":
                            multiple_value = frozenset(_RE_SPLIT_WHITESPACE.split(attr.value.strip()))
                            if len(multiple_value) > 0:
                                attrs[attr.name] = multiple_value
                        else:
                            attrs[attr.name] = attr.value

                if len(attrs) == 0:
                    self.nodes.append((level, tag_name))

                else:

                    if attrs.get("id") and self.options.get("ids_ignore"):
                        if attrs["id"].lower() in self.options["ids_ignore"]:
                            return 0

                    if attrs.get("class") and self.options.get("classes_ignore"):
                        if self.options["classes_ignore"].intersection(attrs["class"]):
                            return 0
                    
                    self.nodes.append((level, tag_name, attrs))

            # Call _iternode() recursively for each of the children
            for i in range(node.v.element.children.length):
                child = <gumbocy.GumboNode *>node.v.element.children.data[i]
                if self._traverse_node(level + 1, child) == 1:
                    break

            if tag_name == b"head" and self.options.get("head_only"):
                return 1

        return 0

    def parse(self):
        """ Do the actual parsing of the HTML with gumbo """
        self.output = gumbocy.gumbo_parse(self.html)

    def listnodes(self, dict options = None):
        """ Return the nodes as a flat list of tuples """

        self.options = options or {}
        self.nesting_limit = self.options.get("nesting_limit", 999)
        
        self.nodes = []

        self._traverse_node(0, self.output.root)

        return self.nodes

    def __dealloc__(self):
        """ Cleanup gumbo memory when the parser is deallocated by Python """
        gumbocy.gumbo_destroy_output(&gumbocy.kGumboDefaultOptions, self.output)
