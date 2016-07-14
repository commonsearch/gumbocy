import re
cimport gumbocy
cimport re2cy
from libcpp.unordered_set cimport unordered_set
from cython.operator cimport dereference as deref
from libcpp.vector cimport vector
from libcpp.map cimport map


cdef extern from "stdio.h":
    int printf(const char* format, ...);

cdef vector[re2cy.ArgPtr] *argp = new vector[re2cy.ArgPtr]()
cdef re2cy.ArgPtr *empty_args = &(deref(argp)[0])

cdef bint re2_search(const char* s, re2cy.RE2 &pattern):
    return re2cy.RE2.PartialMatchN(s, pattern, empty_args, 0)

cdef re2cy.RE2 *_RE2_SEARCH_STYLE_HIDDEN = new re2cy.RE2(r"(display\s*\:\s*none)|(visibility\s*\:\s*hidden)")
cdef re2cy.RE2 *_RE2_EXTERNAL_HREF = new re2cy.RE2(r"^(?:[A-Za-z0-9\+\.\-]+\:)?\/\/")
cdef re2cy.RE2 *_RE2_IGNORED_HREF = new re2cy.RE2(r"^(?:javascript|mailto|ftp|about)\:")

_RE_SPLIT_WHITESPACE = re.compile(r"\s+")

ctypedef enum AttributeNames:
    ATTR_ID,
    ATTR_ROLE,
    ATTR_HREF,
    ATTR_STYLE,
    ATTR_REL,
    ATTR_SRC,
    ATTR_ALT,
    ATTR_NAME,
    ATTR_PROPERTY,
    ATTR_CONTENT

# ATTR_ID = 0
# ATTR_ROLE = 1
# ATTR_HREF = 2
# ATTR_STYLE = 3
# ATTR_REL = 4
# ATTR_SRC = 5
# ATTR_ALT = 6
# ATTR_NAME = 7
# ATTR_PROPERTY = 8
# ATTR_CONTENT = 9

# cdef struct Attributes:
#     int size_classes
#     vector[char*] classes
#     bint has_hidden
#     map[AttributeNames, const char*] values

cdef class Attributes:
    cdef int size_classes
    cdef dict values
    # cdef map[AttributeNames, const char*] values
    # cdef const char* values[10]
    # cdef vector[char*] classes
    cdef list classes
    cdef bint has_hidden

# ctypedef sAttributes Attributes

cdef class HTMLParser:

    # Global parser variables
    cdef int nesting_limit
    cdef bint head_only
    cdef bint has_ids_ignore
    cdef bint has_classes_ignore
    cdef bint has_ids_hidden
    cdef bint has_classes_hidden
    cdef bint has_attributes_whitelist
    cdef bint has_classes_boilerplate
    cdef bint has_ids_boilerplate
    cdef bint has_roles_boilerplate
    cdef bint has_metas_whitelist

    cdef unordered_set[int] tags_ignore
    cdef unordered_set[int] tags_ignore_head_only
    cdef unordered_set[int] tags_boilerplate
    cdef unordered_set[int] tags_boilerplate_bypass
    cdef unordered_set[int] tags_separators

    cdef re2cy.RE2* attributes_whitelist
    cdef re2cy.RE2* metas_whitelist
    cdef re2cy.RE2* classes_ignore
    cdef re2cy.RE2* ids_ignore
    cdef re2cy.RE2* classes_hidden
    cdef re2cy.RE2* ids_hidden
    cdef re2cy.RE2* classes_boilerplate
    cdef re2cy.RE2* ids_boilerplate
    cdef re2cy.RE2* roles_boilerplate

    cdef bint analyze_internal_hyperlinks
    cdef bint analyze_external_hyperlinks
    cdef bint analyze_word_groups

    # Variables reinitialized at each parse()
    cdef list current_stack

    cdef dict analysis

    cdef object current_word_group
    cdef object current_hyperlink

    cdef bint has_output
    cdef gumbocy.GumboOutput* output
    cdef list nodes

    def __cinit__(self, dict options=None):

        options = options or {}

        self.nesting_limit = options.get("nesting_limit", 999)
        self.head_only = options.get("head_only")

        self.analyze_external_hyperlinks = bool(options.get("analyze_external_hyperlinks", True))
        self.analyze_internal_hyperlinks = bool(options.get("analyze_internal_hyperlinks", True))
        self.analyze_word_groups = bool(options.get("analyze_word_groups", True))

        attributes_whitelist = set(options.get("attributes_whitelist") or [])

        classes_ignore = frozenset(options.get("classes_ignore") or [])
        if len(classes_ignore) > 0:
            self.has_classes_ignore = True
            self.classes_ignore = new re2cy.RE2("^(?:" + "|".join(classes_ignore) + ")$")
            attributes_whitelist.add("class")

        ids_ignore = frozenset(options.get("ids_ignore") or [])
        if len(ids_ignore) > 0:
            self.has_ids_ignore = True
            self.ids_ignore = new re2cy.RE2("^(?:" + "|".join(ids_ignore) + ")$")
            attributes_whitelist.add("id")

        classes_hidden = frozenset(options.get("classes_hidden") or [])
        if len(classes_hidden) > 0:
            self.has_classes_hidden = True
            self.classes_hidden = new re2cy.RE2("^(?:" + "|".join(classes_hidden) + ")$")
            attributes_whitelist.add("class")

        ids_hidden = frozenset(options.get("ids_hidden") or [])
        if len(ids_hidden) > 0:
            self.has_ids_hidden = True
            self.ids_hidden = new re2cy.RE2("^(?:" + "|".join(ids_hidden) + ")$")
            attributes_whitelist.add("id")

        classes_boilerplate = frozenset(options.get("classes_boilerplate") or [])
        if len(classes_boilerplate) > 0:
            self.has_classes_boilerplate = True
            self.classes_boilerplate = new re2cy.RE2("^(?:" + "|".join(classes_boilerplate) + ")$")
            attributes_whitelist.add("class")

        ids_boilerplate = frozenset(options.get("ids_boilerplate") or [])
        if len(ids_boilerplate) > 0:
            self.has_ids_boilerplate = True
            self.ids_boilerplate = new re2cy.RE2("^(?:" + "|".join(ids_boilerplate) + ")$")
            attributes_whitelist.add("id")

        roles_boilerplate = frozenset(options.get("roles_boilerplate") or [])
        if len(roles_boilerplate) > 0:
            self.has_roles_boilerplate = True
            self.roles_boilerplate = new re2cy.RE2("^(?:" + "|".join(roles_boilerplate) + ")$")
            attributes_whitelist.add("role")

        metas_whitelist = frozenset(options.get("metas_whitelist") or [])
        if len(metas_whitelist) > 0:
            self.has_metas_whitelist = True
            self.metas_whitelist = new re2cy.RE2("^(?:" + "|".join(metas_whitelist) + ")$")
            attributes_whitelist.add("name")
            attributes_whitelist.add("property")
            attributes_whitelist.add("content")

        # Some options add attributes to the whitelist
        if self.analyze_external_hyperlinks or self.analyze_internal_hyperlinks:
            attributes_whitelist.add("href")
            attributes_whitelist.add("rel")

        # FInally, freeze the attributes whitelist
        self.has_attributes_whitelist = len(attributes_whitelist) > 0
        if self.has_attributes_whitelist:
            self.attributes_whitelist = new re2cy.RE2("^(?:" + "|".join(attributes_whitelist) + ")$")

        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_BODY)
        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_P)
        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_DIV)
        self.tags_ignore_head_only.insert(gumbocy.GUMBO_TAG_SPAN)

        for tag_name in options.get("tags_ignore", []):
            tag = gumbocy.gumbo_tag_enum(tag_name)
            if tag != gumbocy.GUMBO_TAG_UNKNOWN:
                self.tags_ignore.insert(<int> gumbocy.gumbo_tag_enum(tag_name))

        for tag_name in options.get("tags_boilerplate", []):
            tag = gumbocy.gumbo_tag_enum(tag_name)
            if tag != gumbocy.GUMBO_TAG_UNKNOWN:
                self.tags_boilerplate.insert(<int> gumbocy.gumbo_tag_enum(tag_name))

        for tag_name in options.get("tags_boilerplate_bypass", []):
            tag = gumbocy.gumbo_tag_enum(tag_name)
            if tag != gumbocy.GUMBO_TAG_UNKNOWN:
                self.tags_boilerplate_bypass.insert(<int> gumbocy.gumbo_tag_enum(tag_name))

        for tag_name in options.get("tags_separators", []):
            tag = gumbocy.gumbo_tag_enum(tag_name)
            if tag != gumbocy.GUMBO_TAG_UNKNOWN:
                self.tags_separators.insert(<int> gumbocy.gumbo_tag_enum(tag_name))

        self.tags_separators.insert(gumbocy.GUMBO_TAG_BODY)

    cdef bint guess_node_hidden(self, gumbocy.GumboNode* node, Attributes attrs):
        """ Rough guess to check if the element is explicitly hidden.

            Not intended to combat spam!
        """

        if not self.has_attributes_whitelist:
            return False

        # From the HTML5 spec
        if attrs.has_hidden:
            return True

        if self.has_ids_hidden and attrs.values.get(ATTR_ID):
            if re2_search(attrs.values[ATTR_ID], deref(self.ids_hidden)):
                return True

        if self.has_classes_hidden and attrs.size_classes > 0:
            for k in attrs.classes:
                if re2_search(k, deref(self.classes_hidden)):
                    return True

        if attrs.values.get(ATTR_STYLE):
            if re2_search(attrs.values[ATTR_STYLE], deref(_RE2_SEARCH_STYLE_HIDDEN)):
                return True

        return False


    cdef bint guess_node_boilerplate(self, gumbocy.GumboNode* node, Attributes attrs):
        """ Rough guess to check if the element is boilerplate """

        if self.tags_boilerplate.count(<int> node.v.element.tag):
            return True

        # http://html5doctor.com/understanding-aside/
        if node.v.element.tag == gumbocy.GUMBO_TAG_ASIDE:
            if "article" not in self.current_stack:
                return True

        if self.has_classes_boilerplate and attrs.size_classes > 0:
            for k in attrs.classes:
                if re2_search(k, deref(self.classes_boilerplate)):
                    return True

        if self.has_ids_boilerplate and attrs.values.get(ATTR_ID):
            if re2_search(attrs.values[ATTR_ID], deref(self.ids_boilerplate)):
                return True

        if self.has_roles_boilerplate and attrs.values.get(ATTR_ROLE):
            if re2_search(attrs.values[ATTR_ROLE], deref(self.roles_boilerplate)):
                return True

        return False

    cdef Attributes get_attributes(self, gumbocy.GumboNode* node):
        """ Build a dict with all the whitelisted attributes """

        attrs = Attributes()
        # cdef Attributes attrs
        attrs.size_classes = 0
        attrs.has_hidden = 0
        # attrs.values = [""] * 10
        # attrs.classes = []
        attrs.values = {}  # deref(new map[AttributeNames, const char*]())
        # attrs.values[ATTR_ID] = "x"
        # print dict(attrs.values)

        for i in range(node.v.element.attributes.length):

            attr = <gumbocy.GumboAttribute *> node.v.element.attributes.data[i]

            if re2_search(attr.name, deref(self.attributes_whitelist)):

                if attr.name == b"class":
                    multiple_value = frozenset(_RE_SPLIT_WHITESPACE.split(attr.value.strip().lower()))
                    attrs.size_classes = len(multiple_value)
                    if attrs.size_classes > 0:
                        attrs.classes = list(multiple_value)
                        # for k in multiple_value:
                        #     ck = <char *> k
                        #     attrs.classes.push_back(ck)  #  = list(multiple_value)

                elif attr.name == b"id":
                    pystr = str(attr.value).lower()
                    attrs.values[ATTR_ID] = pystr

                elif attr.name == b"style":
                    attrs.values[ATTR_STYLE] = attr.value

                elif attr.name == b"href":
                    attrs.values[ATTR_HREF] = attr.value

                elif attr.name == b"role":
                    pystr = str(attr.value).lower()
                    attrs.values[ATTR_ROLE] = pystr

                elif attr.name == b"rel":
                    pystr = str(attr.value).lower()
                    attrs.values[ATTR_REL] =  pystr

                elif attr.name == b"aria-hidden" and attr.value == b"true":
                    attrs.has_hidden = 1

                elif attr.name == b"hidden":
                    attrs.has_hidden = 1

                elif attr.name == b"alt":
                    attrs.values[ATTR_ALT] = attr.value

                elif attr.name == b"src":
                    attrs.values[ATTR_SRC] = attr.value

                elif attr.name == b"name":
                    pystr = str(attr.value).lower()
                    attrs.values[ATTR_NAME] = pystr

                elif attr.name == b"property":
                    pystr = str(attr.value).lower()
                    attrs.values[ATTR_PROPERTY] = pystr

                elif attr.name == b"content":
                    attrs.values[ATTR_CONTENT] = attr.value

        return attrs

    cdef void close_word_group(self):
        """ Close the current word group """

        if self.current_word_group:
            self.analysis["word_groups"].append(tuple(self.current_word_group))
            self.current_word_group = None


    cdef void add_text(self, text):

        if not self.current_word_group:
            self.current_word_group = [text.strip(), self.current_stack[-1]]
        else:
            self.current_word_group[0] += " " + text.strip()

    cdef void add_hyperlink_text(self, text):
        if self.current_hyperlink:
            self.current_hyperlink[1] += text

    cdef void open_hyperlink(self, Attributes attrs):

        if not attrs.values.get(ATTR_HREF):
            return

        if len(attrs.values[ATTR_HREF]) == 0:
            return

        if re2_search(attrs.values[ATTR_HREF], deref(_RE2_IGNORED_HREF)):
            return

        self.close_hyperlink()
        self.current_hyperlink = [attrs.values[ATTR_HREF], ""]

    cdef void close_hyperlink(self):
        if self.current_hyperlink:
            href = self.current_hyperlink[0]

            # TODO: absolute links to same domain
            if re2_search(href, deref(_RE2_EXTERNAL_HREF)):
                if self.analyze_external_hyperlinks:
                    if href.startswith("http://") or href.startswith("https://") or href.startswith("//"):
                        self.analysis["external_hyperlinks"].append(tuple(self.current_hyperlink))
            else:
                if self.analyze_internal_hyperlinks:
                    self.analysis["internal_hyperlinks"].append(tuple(self.current_hyperlink))

            self.current_hyperlink = None

    cdef bint _traverse_node(self, int level, gumbocy.GumboNode* node, bint is_head, bint is_hidden, bint is_boilerplate, bint is_boilerplate_bypassed, bint is_hyperlink):
        """ Traverses the node tree. Return 1 to stop at this level """

        cdef GumboStringPiece gsp
        cdef const char* tag_name
        cdef int tag_n

        if level > self.nesting_limit:
            return 0

        if node.type == gumbocy.GUMBO_NODE_TEXT:

            if (self.analyze_internal_hyperlinks or self.analyze_external_hyperlinks) and is_hyperlink:
                self.add_hyperlink_text(node.v.text.text)

            if self.analyze_word_groups and not is_head and not is_hidden and (not is_boilerplate or is_boilerplate_bypassed):
                self.add_text(node.v.text.text)

        elif node.type == gumbocy.GUMBO_NODE_ELEMENT:

            tag_n = <int> node.v.element.tag

            if self.head_only and self.tags_ignore_head_only.count(tag_n):
                return 1

            if self.tags_ignore.count(tag_n):
                return 0

            tag_name = gumbocy.gumbo_normalized_tagname(node.v.element.tag)

            # When we find an unknown tag, find its tag_name in the buffer
            if tag_name == b"":
                gsp = node.v.element.original_tag
                gumbo_tag_from_original_text(&gsp)
                py_tag_name = str(gsp.data)[0:gsp.length].lower()  # TODO try to do that only in C!
                tag_name = <const char *> py_tag_name

            # if self.has_attributes_whitelist:

            attrs = self.get_attributes(node)

            if self.has_classes_ignore and attrs.size_classes > 0:
                for v in attrs.classes:
                    if re2_search(v, deref(self.classes_ignore)):
                        return 0

            if self.has_ids_ignore and attrs.values.get(ATTR_ID):
                if re2_search(attrs.values[ATTR_ID], deref(self.ids_ignore)):
                    return 0

            if node.v.element.tag == gumbocy.GUMBO_TAG_TITLE:
                if not self.analysis.get("title"):
                    if node.v.element.children.length > 0:
                        first_child = <gumbocy.GumboNode *> node.v.element.children.data[0]
                        if first_child.type == gumbocy.GUMBO_NODE_TEXT:
                            self.analysis["title"] = first_child.v.text.text
                return 0

            self.current_stack.append(tag_name)

            if node.v.element.tag == gumbocy.GUMBO_TAG_HEAD:
                is_head = 1

            elif node.v.element.tag == gumbocy.GUMBO_TAG_A:
                self.open_hyperlink(attrs)
                is_hyperlink = 1

            elif node.v.element.tag == gumbocy.GUMBO_TAG_IMG:
                self.close_word_group()
                if attrs.values.get(ATTR_ALT):
                    self.add_text(attrs.values[ATTR_ALT])
                    self.close_word_group()

                # Text extraction from image filenames disabled for now
                # if attrs.get("src"):
                #     if not attrs["src"].startswith("data:"):
                #         self.add_text(self._split_filename_words(attrs["src"]))
                #         self.close_word_group()


            if is_head:
                if node.v.element.tag == gumbocy.GUMBO_TAG_LINK:

                    # TODO: more properties
                    if attrs.values.get(ATTR_REL) and attrs.values.get(ATTR_HREF):
                        self.analysis.setdefault("head_links", [])
                        self.analysis["head_links"].append({"rel": attrs.values[ATTR_REL], "href": attrs.values[ATTR_HREF]})

                elif self.has_metas_whitelist and node.v.element.tag == gumbocy.GUMBO_TAG_META:

                    if attrs.values.get(ATTR_CONTENT):

                        if attrs.values.get(ATTR_NAME):
                            if re2_search(attrs.values[ATTR_NAME], deref(self.metas_whitelist)):
                                self.analysis.setdefault("head_metas", {})
                                self.analysis["head_metas"][attrs.values[ATTR_NAME]] = str(attrs.values[ATTR_CONTENT]).strip()

                        elif attrs.values.get(ATTR_PROPERTY):
                            if re2_search(attrs.values[ATTR_PROPERTY], deref(self.metas_whitelist)):
                                self.analysis.setdefault("head_metas", {})
                                self.analysis["head_metas"][attrs.values[ATTR_PROPERTY]] = str(attrs.values[ATTR_CONTENT]).strip()

                elif node.v.element.tag == gumbocy.GUMBO_TAG_BASE:
                    if attrs.values.get(ATTR_HREF) and "base_url" not in self.analysis:
                        self.analysis["base_url"] = attrs.values[ATTR_HREF]

            # TODO is_article

            if not is_hidden:
                is_hidden = self.guess_node_hidden(node, attrs)

            if is_boilerplate and not is_boilerplate_bypassed:
                if self.tags_boilerplate_bypass.count(tag_n):
                    is_boilerplate_bypassed = True

            if not is_boilerplate:
                is_boilerplate = self.guess_node_boilerplate(node, attrs)

            # print " " * level, "BOILER", tag_name, is_boilerplate, dict(attrs.values), attrs.classes

            # Close the word group
            if self.tags_separators.count(tag_n):
                self.close_word_group()

            # Call _traverse_node() recursively for each of the children
            for i in range(node.v.element.children.length):
                child = <gumbocy.GumboNode *>node.v.element.children.data[i]
                if self._traverse_node(level + 1, child, is_head, is_hidden, is_boilerplate, is_boilerplate_bypassed, is_hyperlink) == 1:
                    break

            # Close the word group
            if self.tags_separators.count(tag_n):
                self.close_word_group()

            self.current_stack.pop()

            if node.v.element.tag == gumbocy.GUMBO_TAG_A:
                self.close_hyperlink()

            if node.v.element.tag == gumbocy.GUMBO_TAG_HEAD:
                if self.head_only:
                    return 1

        return 0

    def parse(self, char* html):
        """ Do the actual parsing of the HTML with gumbo """

        self.output = gumbocy.gumbo_parse(html)
        self.has_output = 1

    def analyze(self):
        """ Traverse the parsed tree and return the results """

        self.analysis = {}

        if self.analyze_internal_hyperlinks:
            self.analysis["internal_hyperlinks"] = []

        if self.analyze_external_hyperlinks:
            self.analysis["external_hyperlinks"] = []

        if self.analyze_word_groups:
            self.analysis["word_groups"] = []

        self.current_stack = []
        self.current_word_group = None
        self.current_hyperlink = None

        self._traverse_node(0, self.output.root, 0, 0, 0, 0, 0)

        return self.analysis

    #
    # Older listnodes() API support
    #

    def listnodes(self):
        """ Return the nodes as a flat list of tuples """

        self.nodes = []

        self._traverse_node_simple(0, self.output.root)

        return self.nodes

    cdef bint _traverse_node_simple(self, int level, gumbocy.GumboNode* node):
        """ Traverses the node tree. Return 1 to stop at this level """

        cdef GumboStringPiece gsp

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

            # When we find an unknown tag, find its tag_name in the buffer
            if tag_name == b"":
                gsp = node.v.element.original_tag
                gumbo_tag_from_original_text(&gsp)
                py_tag_name = str(gsp.data)[0:gsp.length].lower()  # TODO try to do that only in C!
                tag_name = <const char *> py_tag_name

            if self.has_attributes_whitelist:

                # Build a dict with all the whitelisted attributes
                has_attrs = False
                attrs = False
                for i in range(node.v.element.attributes.length):
                    attr = <gumbocy.GumboAttribute *> node.v.element.attributes.data[i]
                    attr_name = str(attr.name)
                    if re2_search(attr_name, deref(self.attributes_whitelist)):
                        if attr_name == b"class":
                            multiple_value = frozenset(_RE_SPLIT_WHITESPACE.split(attr.value.strip().lower()))
                            if len(multiple_value):
                                if self.has_classes_ignore:
                                    for v in multiple_value:
                                        if re2_search(v, deref(self.classes_ignore)):
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
                        if attrs.get("id") and re2_search(attrs["id"].lower(), deref(self.ids_ignore)):
                            return 0

                    self.nodes.append((level, tag_name, attrs))

            else:
                self.nodes.append((level, tag_name))

            # Call _iternode() recursively for each of the children
            for i in range(node.v.element.children.length):
                child = <gumbocy.GumboNode *>node.v.element.children.data[i]
                if self._traverse_node_simple(level + 1, child) == 1:
                    break

            if node.v.element.tag == gumbocy.GUMBO_TAG_HEAD and self.head_only:
                return 1

        return 0

    def __dealloc__(self):
        """ Cleanup gumbo memory when the parser is deallocated by Python """

        if self.has_output:
            gumbocy.gumbo_destroy_output(&gumbocy.kGumboDefaultOptions, self.output)
            self.has_output = 0
