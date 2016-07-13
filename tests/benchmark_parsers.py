# Usage: python -m cProfile -s cumtime tests/benchmark_parsers.py

import os
import sys
sys.path.insert(-1, os.getcwd())

import requests
import timeit
import html5lib
import lxml.html
import gumbocy
import gumbo
import bs4

if not os.path.isfile("tests/_benchmark_fixture.html"):
    url = 'https://raw.githubusercontent.com/whatwg/html/d8717d8831c276ca65d2d44bbf2ce4ce673997b9/source'
    html = requests.get(url).content
    with open("tests/_benchmark_fixture.html", "w") as f:
        f.write(html)

with open("tests/_benchmark_fixture.html", "r") as f:
    html = f.read()
    html_unicode = html.decode("utf-8")


def bench(name, func):
    print('{}: {:.3f} seconds'.format(name, min(timeit.repeat(func, number=1, repeat=3))))


def benchmark_gumbocy():
    parser = gumbocy.HTMLParser(options={
        "attributes_whitelist": ["id", "class", "style"]
    })
    parser.parse(html)
    nodes = parser.listnodes()

    divs_count = 0
    for node in nodes:
        if node[1] == "div":
            divs_count += 1
    print "Gumbocy: ", divs_count


def benchmark_gumbo_bs3():
    parser = gumbo.soup_parse(html_unicode)
    divs = parser.findAll("div")
    print "gumbo bs3", len(divs)


def benchmark_lxml_raw():
    parsed = lxml.html.fromstring(html)
    divs = parsed.findall(".//div")
    print "lxml raw", len(divs)


def benchmark_html5lib_bs4():
    parser = bs4.BeautifulSoup(html, "html5lib")
    divs = parser.find_all("div")
    print "html5lib bs4", len(divs)


def benchmark_htmlparser_bs4():
    parser = bs4.BeautifulSoup(html, "html.parser")
    divs = parser.find_all("div")
    print "html.parser bs4", len(divs)


bench("benchmark_gumbocy", benchmark_gumbocy)
bench("benchmark_gumbo_bs3", benchmark_gumbo_bs3)
bench("benchmark_lxml_raw", benchmark_lxml_raw)
bench("benchmark_html5lib_bs4", benchmark_html5lib_bs4)
bench("benchmark_htmlparser_bs4", benchmark_htmlparser_bs4)
