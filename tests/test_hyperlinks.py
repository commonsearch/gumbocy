import gumbocy
from test_word_groups import TAGS_SEPARATORS


def _links(html, url=None):
    parser = gumbocy.HTMLParser(options={
        "tags_separators": TAGS_SEPARATORS
    })
    parser.parse(html)
    ret = parser.analyze(url=url)
    return {
        "all": ret["internal_hyperlinks"] + ret["external_hyperlinks"],
        "internal": ret["internal_hyperlinks"],
        "external": ret["external_hyperlinks"]
    }


def test_get_hyperlinks():
    links = _links("""<html><head><title>Test title</title></head><body>x</body></html>""")
    assert len(links["all"]) == 0

    links = _links("""<html><head><title>Test title</title></head><body>
        <a name="x">Y</a>
    </body></html>""")
    assert len(links["all"]) == 0

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="">Y</a>
    </body></html>""")
    assert len(links["all"]) == 0

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="ftp://test.com">Y</a>
    </body></html>""")
    assert len(links["all"]) == 0

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="javascript:hello()">Y</a>
    </body></html>""")
    assert len(links["all"]) == 0

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="mailto:contact@example.com">Y</a>
    </body></html>""")
    assert len(links["all"]) == 0

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="http://sub.test.com/page1?q=2&a=b#xxx" rel="nofollow">Y</a>
    </body></html>""")
    assert len(links["all"]) == 1
    assert links["external"][0][0] == "http://sub.test.com/page1?q=2&a=b#xxx"
    assert links["external"][0][1] == "Y"
    assert links["external"][0][2] == "nofollow"

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="/page1?q=2&a=b#xxx">Y X</a>
    </body></html>""", url="http://sub.test.com/page2")
    assert len(links["all"]) == 1
    assert links["internal"][0][0] == "/page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y X"
    assert links["internal"][0][2] is None

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="../page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["internal"][0][0] == "../page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y Z"

    # Absolute links to the same netloc are still internal
    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="http://sub.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert len(links["external"]) == 0
    assert links["internal"][0][0] == "/page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y Z"

    # Cross-scheme links are still considered internal
    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="https://sub.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["internal"][0][0] == "/page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y Z"

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="http://sub.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="https://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["internal"][0][0] == "/page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y Z"

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="http://sub.test.com/sub.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["internal"][0][0] == "/sub.test.com/page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y Z"

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="//sub.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["internal"][0][0] == "/page1?q=2&a=b#xxx"
    assert links["internal"][0][1] == "Y Z"

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="//sub2.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["external"][0][0] == "http://sub2.test.com/page1?q=2&a=b#xxx"
    assert links["external"][0][1] == "Y Z"

    links = _links("""<html><head><title>Test title</title></head><body>
        <a href="https://sub2.test.com/page1?q=2&a=b#xxx">Y Z</a>
    </body></html>""", url="http://sub.test.com/page2/x.html")
    assert len(links["all"]) == 1
    assert links["external"][0][0] == "https://sub2.test.com/page1?q=2&a=b#xxx"
    assert links["external"][0][1] == "Y Z"

    # TODO resolution tests
