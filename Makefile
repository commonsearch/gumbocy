GUMBO_VERSION ?= 0.10.1

clean:
	rm -rf *.so build *.c *.cpp *.html dist .cache tests/__pycache__ *.rst

cythonize:
	cython --cplus -2 --warning-extra --annotate gumbocy.pyx

build_ext: clean cythonize
ifeq ($(GUMBOCY_PYTHON_VERSION), pypy)
	/opt/pypy/bin/pypy setup.py build_ext --inplace -Igumbo-parser/src -Lgumbo-parser/.libs -Rgumbo-parser/.libs
else
	python setup.py build_ext --inplace -Igumbo-parser/src -Lgumbo-parser/.libs -Rgumbo-parser/.libs
endif

rst:
	pandoc --from=markdown --to=rst --output=README.rst README.md

virtualenv:
	rm -rf venv
	virtualenv venv
	venv/bin/pip install -r requirements.txt

test: build_ext
ifeq ($(GUMBOCY_PYTHON_VERSION), pypy)
	/opt/pypy/bin/py.test tests/ -vs
else
	py.test tests/ -vs
endif

gumbo_build:
	curl -L https://github.com/google/gumbo-parser/archive/v$(GUMBO_VERSION).tar.gz > gumbo.tgz
	rm -rf gumbo-parser-$(GUMBO_VERSION) gumbo-parser
	tar zxf gumbo.tgz
	mv gumbo-parser-$(GUMBO_VERSION) gumbo-parser
	cd gumbo-parser && ./autogen.sh && ./configure && make
	rm -rf gumbo.tgz

docker_build:
	docker build -t commonsearch/gumbocy .

docker_shell:
	docker run -e GUMBOCY_PYTHON_VERSION -v "$(PWD):/cosr/gumbocy:rw" -w /cosr/gumbocy -i -t commonsearch/gumbocy bash

docker_test:
	docker run -e GUMBOCY_PYTHON_VERSION -v "$(PWD):/cosr/gumbocy:rw" -w /cosr/gumbocy -i -t commonsearch/gumbocy make test
