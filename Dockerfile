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
	python-dev



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