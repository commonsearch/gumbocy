import gumbocy
import pytest

TAGS_SEPARATORS = frozenset([
    "body",

    # http://www.w3.org/TR/html5/grouping-content.html#grouping-content
    "p", "pre", "blockquote", "ul", "ol", "li", "dl", "dt", "dd", "figure", "figcaption",

    "br", "img",

    "h1", "h2", "h3", "h4", "h5", "h6"
])


SAMPLES = [
    {
        "html": """ <p>hello</p> """,
        "groups": [
            ("hello", "p")
        ]
    },

    # A <body> is automatically added
    {
        "html": """ nobody """,
        "groups": [
            ("nobody", "body")
        ]
    },

    # span
    {
        "html": """ <p>pre <span>link</span> post</p> """,
        "groups": [
            ("pre link post", "p")
        ]
    },

    # a
    {
        "html": """ <p>pre <a href="#">link</a> post</p> """,
        "groups": [
            ("pre link post", "p")
        ]
    },

    # mid p
    {
        "html": """ <p>pre </p><ul><li>li1 x</li></ul> mid <p> post </p> """,
        "groups": [
            ("pre", "p"),
            ("li1 x", "li"),
            ("mid", "body"),
            ("post", "p")
        ]
    },

    # Lists
    {
        "html": """ pre <ul><li>li1</li><li>li2</li></ul> post """,
        "groups": [
            ("pre", "body"),
            ("li1", "li"),
            ("li2", "li"),
            ("post", "body")
        ]
    },

    # HR with illegal <p>. "post" is actually part of <body>.
    {
        "html": """ <p>pre <hr/> post</p>""",
        "groups": [
            ("pre", "p"),
            ("post", "body")
        ]
    },

    # Non-closed p tag.
    {
        "html": """ pre <p> post""",
        "groups": [
            ("pre", "body"),
            ("post", "p")
        ]
    },

    # BR
    {
        "html": """ <p>pre <br/> post </p>""",
        "groups": [
            ("pre", "p"),
            ("post", "p")
        ]
    },

    # IMG filename + alt
    {
        "html": """ <p> pre <img src="/test/dir/maceo_parker.jpg" alt="james brown"> post </p>""",
        "groups": [
            ("pre", "p"),
            ("james brown", "img"),
            # ("maceo parker", "img"),
            ("post", "p")
        ]
    },

    # IMG with dataURIs are ignored
    {
        "html": """<p> pre <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot" /> post </p>""",
        "groups": [
            ("pre", "p"),
            ("Red dot", "img"),
            ("post", "p")
        ]
    },
]


# TODO: good coverage of http://www.w3.org/html/wg/drafts/html/master/syntax.html
@pytest.mark.parametrize(("sample"), SAMPLES)
def test_get_word_groups(sample):

    parser = gumbocy.HTMLParser(options={
        "tags_separators": TAGS_SEPARATORS,
        "attributes_whitelist": ["src", "alt"]
    })
    parser.parse(sample["html"])
    parsed = parser.analyze()

    for i, group in enumerate(parsed["word_groups"]):
        assert group == sample["groups"][i]

    assert len(parsed["word_groups"]) == len(sample["groups"])
