import re
cimport gumbocy
from libcpp.unordered_set cimport unordered_set


cdef extern from "stdio.h":
    int printf(const char* format, ...);


_RE_SPLIT_WHITESPACE = re.compile(r"\s+")


cdef class HTMLParser:

    cdef char* html
    cdef gumbocy.GumboOutput* output
    cdef list nodes

    cdef int nesting_limit
    cdef bint head_only
    cdef bint has_ids_ignore
    cdef bint has_classes_ignore
    cdef bint has_attributes_whitelist
    cdef unordered_set[int] tags_ignore
    cdef unordered_set[int] tags_ignore_head_only

    cdef frozenset classes_ignore
    cdef frozenset attributes_whitelist
    cdef frozenset ids_ignore


    def __cinit__(self, char* html):
        self.html = html

    cdef bint _traverse_node(self, int level, gumbocy.GumboNode* node):
        """ Traverses the node tree. Return 1 to stop at this level """

        if level > self.nesting_limit:
            return 0

        if node.type == gumbocy.GUMBO_NODE_TEXT:
            self.nodes.append((level, None, node.v.text.text))

        elif node.type == gumbocy.GUMBO_NODE_ELEMENT:

            tag_n = <int> node.v.element.tag

            if self.head_only and self.tags_ignore_head_only.count(tag_n):
                return 1

            if self.tags_ignore.count(tag_n):
                return 0

            tag_name = gumbocy.gumbo_normalized_tagname(node.v.element.tag)

            if self.has_attributes_whitelist:

                # Build a dict with all the whitelisted attributes
                has_attrs = False
                attrs = False
                for i in range(node.v.element.attributes.length):
                    attr = <gumbocy.GumboAttribute *> node.v.element.attributes.data[i]
                    attr_name = str(attr.name)
                    if attr_name in self.attributes_whitelist:
                        if attr_name == b"class":
                            multiple_value = frozenset(_RE_SPLIT_WHITESPACE.split(attr.value.strip().lower()))
                            if len(multiple_value):
                                if self.has_classes_ignore:
                                    for v in multiple_value:
                                        if v in self.classes_ignore:
                                            return 0

                                if not has_attrs:
                                    attrs = {}
                                    has_attrs = True
                                attrs[attr_name] = multiple_value

                        else:

                            if not has_attrs:
                                attrs = {}
                                has_attrs = True
                            attrs[attr_name] = attr.value

                if not has_attrs:
                    self.nodes.append((level, tag_name))

                else:

                    if self.has_ids_ignore:
                        if attrs.get("id") and attrs["id"].lower() in self.ids_ignore:
                            return 0

                    self.nodes.append((level, tag_name, attrs))

            else:
                self.nodes.append((level, tag_name))

            # Call _iternode() recursively for each of the children
            for i in range(node.v.element.children.length):
                child = <gumbocy.GumboNode *>node.v.element.children.data[i]
                if self._traverse_node(level + 1, child) == 1:
                    break

            if node.v.element.tag == gumbocy.GUMBO_TAG_HEAD and self.head_only:
                return 1

        return 0

    def parse(self):
        """ Do the actual parsing of the HTML with gumbo """
        self.output = gumbocy.gumbo_parse(self.html)

    def listnodes(self, dict options=None):
        """ Return the nodes as a flat list of tuples """

        options = options or {}
        self.nesting_limit = options.get("nesting_limit", 999)
        self.head_only = options.get("head_only")

        self.has_classes_ignore = options.get("classes_ignore")
        if self.has_classes_ignore:
            self.classes_ignore = frozenset(options["classes_ignore"])

        self.has_ids_ignore = options.get("ids_ignore")
        if self.has_ids_ignore:
            self.ids_ignore = frozenset(options["ids_ignore"])

        self.has_attributes_whitelist = options.get("attributes_whitelist")
        if self.has_attributes_whitelist:
            self.attributes_whitelist = frozenset(options.get("attributes_whitelist") or [])

        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_BODY)
        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_P)
        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_DIV)
        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_SPAN)

        for tag_name in options.get("tags_ignore", []):
            self.tags_ignore.insert(<int> gumbocy.gumbo_tag_enum(tag_name))

        self.nodes = []

        self._traverse_node(0, self.output.root)

        return self.nodes

    def __dealloc__(self):
        """ Cleanup gumbo memory when the parser is deallocated by Python """
        gumbocy.gumbo_destroy_output(&gumbocy.kGumboDefaultOptions, self.output)
