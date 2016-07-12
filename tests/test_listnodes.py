import gumbocy


def listnodes(html, options=None):
    parser = gumbocy.HTMLParser(options=options)
    parser.parse(html)
    return parser.listnodes()


def test_basic():
    html = """
        <html>
            <HEAD><title>HW</title></head>
            <body> Hello <a href="http://example.com" id="i" class="c">world</a><br/></body>
        </html >
    """

    iterations = 1  # 300000
    for _ in range(0, iterations):
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


def test_head_only():
    html = """
        <html>
            <HEAD><title>HW</title></head>
            <body> Hello <a href="http://example.com" id="i">world</a><br class="c ign"/></body>
        </html >
    """

    nodes = listnodes(html, {
        "head_only": True
    })
    assert nodes == [
        (0, "html"),
            (1, "head"),
                (2, "title"),
                    (3, None, "HW")
    ]

    html = """
        <html>
            <p>test</p><title>HW</title>
            <body> Hello <a href="http://example.com" id="i">world</a><br class="c ign"/></body>
        </html >
    """

    nodes = listnodes(html, {
        "head_only": True
    })
    assert nodes == [
        (0, "html"),
            (1, "head")
    ]


def test_unknown_tags():
    html = """
        <html>
            <head></head>
            <body><NEW_TAG class='xx'>inline text</NEW_TAG><new_tag_2 /></body>
        </html >
    """

    nodes = listnodes(html, {
        "attributes_whitelist": ["class"],
        "tags_ignore": "new_tag"  # We can't ignore unknown tags at the Gumbocy level (for now?)
    })

    assert nodes == [
        (0, "html"),
            (1, "head"),
            (1, "body"),
                (2, "new_tag", {'class': frozenset(['xx'])}),
                    (3, None, "inline text"),
                (2, "new_tag_2")
    ]
