import gumbocy


def listnodes(html, options=None):
    parser = gumbocy.HTMLParser(html)
    parser.parse()
    return parser.listnodes(options=options)


def test_basic():
    html = """
        <html>
            <HEAD><title>HW</title></head>
            <body> Hello <a href="http://example.com" id="i" class="c">world</a><br/></body>
        </html >
    """

    nodes = listnodes(html, {"attributes_whitelist": ["href"]})
    assert nodes == [
        (0, "html"),
            (1, "head"),
                (2, "title"),
                    (3, None, "HW"),
            (1, "body"),
                (2, None, " Hello "),
                (2, "a", {"href": "http://example.com"}),
                    (3, None, "world"),
                (2, "br")
    ]


def test_classes():
    html = """
        <html>
            <head></head>
            <body><p class="para graph  "></p></body>
        </html >
    """

    nodes = listnodes(html, {"attributes_whitelist": ["class"]})
    assert nodes == [
        (0, "html"),
            (1, "head"),
            (1, "body"),
                (2, "p", {"class": frozenset(["para", "graph"])})
    ]


def test_ignore():
    html = """
        <html>
            <HEAD><title>HW</title></head>
            <body> Hello <a href="http://example.com" id="i">world</a><br class="c ign"/></body>
        </html >
    """

    nodes = listnodes(html, {
        "attributes_whitelist": ["class", "id"],
        "ids_ignore": ["i"],
        "classes_ignore": set(["ign"]),
        "tags_ignore": ["title"]
    })
    assert nodes == [
        (0, "html"),
            (1, "head"),
            (1, "body"),
                (2, None, " Hello ")
    ]
