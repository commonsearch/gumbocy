FROM debian:jessie

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
	curl \
	automake \
	gcc \
	g++ \
	make \
	libtool \
	ca-certificates \
	python-pip \
	python-dev \
	bzip2

RUN mkdir -p /cosr/gumbocy

ADD Makefile /Makefile

ADD requirements.txt /requirements.txt
RUN pip install -r requirements.txt

RUN make gumbo_build

# Install gumbo system-wide
RUN cd gumbo-parser && make install && ldconfig


# Optional dependencies for benchmarking
RUN apt-get install -y --no-install-recommends \
	libxml2-dev \
	libxslt1-dev \
	zlib1g-dev

ADD requirements-benchmark.txt /requirements-benchmark.txt
RUN pip install -r requirements-benchmark.txt
RUN ln -s /usr/local/lib/libgumbo.so /usr/local/lib/python2.7/dist-packages/gumbo/libgumbo.so


# Install PyPy
RUN curl -L 'https://bitbucket.org/squeaky/portable-pypy/downloads/pypy-5.3.1-linux_x86_64-portable.tar.bz2' -o /pypy.tar.bz2 && \
  mkdir -p /opt/pypy/ && tar jxvf /pypy.tar.bz2 -C /opt/pypy/  --strip-components=1 && \
  rm /pypy.tar.bz2

RUN /opt/pypy/bin/pypy -m ensurepip
RUN /opt/pypy/bin/pip install -r /requirements.txt
RUN /opt/pypy/bin/pip install -r /requirements-benchmark.txt
