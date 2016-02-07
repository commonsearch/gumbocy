clean:
	rm -rf *.so build *.c *.html dist .cache tests/__pycache__ *.rst

cythonize:
	cython --warning-extra --annotate gumbocy.pyx

build_ext: clean cythonize
	python setup.py build_ext --inplace

rst:
	pandoc --from=markdown --to=rst --output=README.rst README.md

virtualenv:
	rm -rf venv
	virtualenv venv
	venv/bin/pip install -r requirements.txt

test: build_ext
	py.test tests/ -vs