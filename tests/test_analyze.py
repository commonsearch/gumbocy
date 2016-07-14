import gumbocy
from test_word_groups import TAGS_SEPARATORS


def analyze(html, options=None):
    parser = gumbocy.HTMLParser(options=options)
    parser.parse(html)
    return parser.analyze()


def test_separators():
    html = """
        <p>text</p>
        <p>text 2</p>
        <p>pre<p>inner</p></p>
    """

    analyzed = analyze(html, options={
        "tags_separators": ["p"]
    })

    assert analyzed["word_groups"] == [
        ("text", "p"),
        ("text 2", "p"),
        ("pre", "p"),
        ("inner", "p")
    ]

    # More word group tests in test_word_groups.py


def test_hidden_text():

    html = """<html><head></head><body>
        <!-- comment -->
        text
        <div>textp</div>
        <div style='display: none;'>hidden by display</div>
        <div class='_class_noindex'>ignored by class_noindex</div>
        <div class='_class_noindex class2'>ignored by class_noindex 2</div>
        <div hidden>hidden by html5 attribute</div>
        <div aria-hidden="true">hidden by aria</div>
        <div aria-hidden="false">not_aria</div>
        <div style='visibility: hidden;'>hidden by visibility</div>
    </body></html>"""

    analyzed = analyze(html, options={
        "attributes_whitelist": ["style", "hidden", "aria-hidden"],
        "classes_hidden": ["_class_hidden"],
        "ids_hidden": ["_id_hidden"],
        "tags_separators": ["div"],
        "classes_ignore": ["_class_noindex"]
    })

    assert analyzed["word_groups"] == [
        ("text", "body"),
        ("textp", "div"),
        ("not_aria", "div")
    ]


def test_hidden_siblings():

    html = """
<span class='login facebook'>
Sign in with Facebook
</span>
<span class='login'>Or use your Businessweek account</span>
"""

    analyzed = analyze(html, options={
        "classes_boilerplate": ["login"]
    })

    assert analyzed["word_groups"] == []


def test_boilerplate_text():

    html = """<html><head></head><body>

        <header>
            Boilerplate
            <h2>Title</h2>
        </header>

        <div class="classboil">x</div>
        <div id="idboil">y</div>
        <div role="roleboil">z</div>

        <h2>Title 2</h2>
    </body></html>"""

    analyzed = analyze(html, options={
        "attributes_whitelist": ["id", "class", "role"],
        "tags_boilerplate": ["header"],
        "tags_boilerplate_bypass": ["h2"],
        "classes_boilerplate": ["classboil"],
        "ids_boilerplate": ["idboil"],
        "roles_boilerplate": ["roleboil"],
        "tags_separators": TAGS_SEPARATORS
    })

    assert analyzed["word_groups"] == [
        ("Title", "h2"),
        ("Title 2", "h2")
    ]


def test_title():

    html = """ <title>test 1</title> <title>test 2</title> """

    analyzed = analyze(html, options={
    })

    assert analyzed["title"] == "test 1"
    assert len(analyzed["word_groups"]) == 0


def test_head_metas():

    html = """<html>
        <head>
            <meta name="Description" content=" This   is a &lt;summary&gt;!" />
            <meta name="Description2" content=" This2   is a &lt;summary&gt;!" />
        </head>
        <body>This is &lt;body&gt; text</body>
    </html>"""

    analyzed = analyze(html, options={
        "metas_whitelist": ["description"]
    })

    assert analyzed["head_metas"] == {"description": "This   is a <summary>!"}
