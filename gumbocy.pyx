import re
cimport gumbocy
cimport re2cy
from libcpp.unordered_set cimport unordered_set
from cython.operator cimport dereference as deref
from libcpp.vector cimport vector


cdef extern from "stdio.h":
    int printf(const char* format, ...);

cdef vector[re2cy.ArgPtr] *argp = new vector[re2cy.ArgPtr]()
cdef re2cy.ArgPtr *empty_args = &(deref(argp)[0])

cdef bint re2_search(char* s, re2cy.RE2 &pattern):
    return re2cy.RE2.PartialMatchN(s, pattern, empty_args, 0)

cdef re2cy.RE2 *_RE2_SEARCH_STYLE_HIDDEN = new re2cy.RE2(r"(display\s*\:\s*none)|(visibility\s*\:\s*hidden)")

_RE_EXTERNAL_HREF = re.compile(r"^([A-Za-z0-9\+\.\-]+\:)?\/\/")
_RE_SPLIT_WHITESPACE = re.compile(r"\s+")

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

    cdef set attributes_whitelist
    cdef frozenset metas_whitelist

    cdef frozenset classes_ignore
    cdef frozenset ids_ignore

    cdef frozenset classes_hidden
    cdef frozenset ids_hidden

    cdef frozenset classes_boilerplate
    cdef frozenset ids_boilerplate
    cdef frozenset roles_boilerplate

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

        self.classes_ignore = frozenset(options.get("classes_ignore") or [])
        self.has_classes_ignore = len(self.classes_ignore) > 0

        self.ids_ignore = frozenset(options.get("ids_ignore") or [])
        self.has_ids_ignore = len(self.ids_ignore) > 0

        self.classes_hidden = frozenset(options.get("classes_hidden") or [])
        self.has_classes_hidden = len(self.classes_hidden) > 0

        self.ids_hidden = frozenset(options.get("ids_hidden") or [])
        self.has_ids_hidden = len(self.ids_hidden) > 0

        self.classes_boilerplate = frozenset(options.get("classes_boilerplate") or [])
        self.has_classes_boilerplate = len(self.classes_boilerplate) > 0

        self.ids_boilerplate = frozenset(options.get("ids_boilerplate") or [])
        self.has_ids_boilerplate = len(self.ids_boilerplate) > 0

        self.roles_boilerplate = frozenset(options.get("roles_boilerplate") or [])
        self.has_roles_boilerplate = len(self.roles_boilerplate) > 0

        self.attributes_whitelist = set(options.get("attributes_whitelist") or [])

        # Some options add attributes to the whitelist
        if self.analyze_external_hyperlinks or self.analyze_internal_hyperlinks:
            self.attributes_whitelist.add("href")
            self.attributes_whitelist.add("rel")

        if self.has_roles_boilerplate:
            self.attributes_whitelist.add("roles")

        if self.has_ids_boilerplate or self.has_ids_hidden or self.has_ids_ignore:
            self.attributes_whitelist.add("id")

        if self.has_classes_boilerplate or self.has_classes_hidden or self.has_classes_ignore:
            self.attributes_whitelist.add("class")

        self.has_attributes_whitelist = len(self.attributes_whitelist) > 0

        self.metas_whitelist = frozenset(options.get("metas_whitelist") or [])
        self.has_metas_whitelist = len(self.metas_whitelist) > 0

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

    cdef bint guess_node_hidden(self, gumbocy.GumboNode* node, dict attrs):
        """ Rough guess to check if the element is explicitly hidden.

            Not intended to combat spam!
        """

        if not self.has_attributes_whitelist:
            return False

        # From the HTML5 spec
        if "hidden" in attrs:
            return True

        if attrs.get("aria-hidden") == "true":
            return True

        if self.has_ids_hidden:
            if attrs.get("id") and attrs["id"].lower() in self.ids_hidden:
                return True

        if self.has_classes_hidden:
            if attrs.get("class"):
                for k in attrs.get("class"):
                    if k in self.classes_hidden:
                        return True

        if attrs.get("style"):
            if re2_search(attrs["style"], deref(_RE2_SEARCH_STYLE_HIDDEN)):
                return True

        return False


    cdef bint guess_node_boilerplate(self, gumbocy.GumboNode* node, dict attrs):
        """ Rough guess to check if the element is boilerplate """

        if self.tags_boilerplate.count(<int> node.v.element.tag):
            return True

        # http://html5doctor.com/understanding-aside/
        if node.v.element.tag == gumbocy.GUMBO_TAG_ASIDE:
            if "article" not in self.current_stack:
                return True

        if not self.has_attributes_whitelist:
            return False

        if not attrs:
            return False

        if self.has_classes_boilerplate:
            if attrs.get("class"):
                for k in attrs.get("class"):
                    if k in self.classes_boilerplate:
                        return True

        if self.has_ids_boilerplate:
            if attrs.get("id") and attrs["id"].lower() in self.ids_boilerplate:
                return True

        if self.has_roles_boilerplate:
            if attrs.get("role") and attrs["role"].lower() in self.roles_boilerplate:
                return True

        return False

    cdef get_attributes(self, gumbocy.GumboNode* node):
        """ Build a dict with all the whitelisted attributes """

        has_attrs = False

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
            return {}

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

    cdef void open_hyperlink(self, attrs):
        href = attrs.get("href")
        if not href:
            return

        if href.startswith("javascript:") or href.startswith("mailto:") or href.startswith("about:"):
            return

        self.close_hyperlink()
        self.current_hyperlink = [href, ""]

    cdef void close_hyperlink(self):
        if self.current_hyperlink:
            href = self.current_hyperlink[0]

            # TODO: absolute links to same domain
            if _RE_EXTERNAL_HREF.search(href):
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

            attrs = {}
            if self.has_attributes_whitelist:

                attrs = self.get_attributes(node)

                if attrs == 0:
                    return 0

                if attrs:
                    if self.has_ids_ignore:
                        if attrs.get("id") and attrs["id"].lower() in self.ids_ignore:
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
                if attrs.get("alt"):
                    self.add_text(attrs["alt"])
                    self.close_word_group()

                # Text extraction from image filenames disabled for now
                # if attrs.get("src"):
                #     if not attrs["src"].startswith("data:"):
                #         self.add_text(self._split_filename_words(attrs["src"]))
                #         self.close_word_group()


            if is_head:
                if node.v.element.tag == gumbocy.GUMBO_TAG_LINK:
                    self.analysis.setdefault("head_links", [])
                    self.analysis["head_links"].append(attrs)

                elif self.has_metas_whitelist and node.v.element.tag == gumbocy.GUMBO_TAG_META:
                    meta_name = (attrs.get("name") or attrs.get("property") or "").lower()
                    if meta_name in self.metas_whitelist:

                        self.analysis.setdefault("head_metas", {})
                        self.analysis["head_metas"][meta_name] = (attrs.get("content") or "").strip()

                elif node.v.element.tag == gumbocy.GUMBO_TAG_BASE:
                    if attrs.get("href") and "base_url" not in self.analysis:
                        self.analysis["base_url"] = attrs["href"]

            # TODO is_article

            if not is_hidden:
                is_hidden = self.guess_node_hidden(node, attrs)

            if is_boilerplate and not is_boilerplate_bypassed:
                if self.tags_boilerplate_bypass.count(tag_n):
                    is_boilerplate_bypassed = True

            if not is_boilerplate:
                is_boilerplate = self.guess_node_boilerplate(node, attrs)

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
