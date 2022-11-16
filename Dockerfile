# Define custom function directory
ARG FUNCTION_DIR="/function"

FROM python:3.8-buster as build-image

# Include global arg in this stage of the build
ARG FUNCTION_DIR

# Install aws-lambda-cpp build dependencies
RUN apt-get update && \
  apt-get install -y \
  g++ \
  make \
  cmake \
  unzip \
  git \
  libcurl4-openssl-dev wget curl git net-tools libglib2.0-* glibc-source tar jq libpcap-dev build-essential apt-transport-https ca-certificates curl software-properties-common gnupg2 postgresql postgresql-contrib unzip libssl-dev git libevent-dev pkg-config gconf-service libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 ca-certificates fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils

# Copy function code
RUN mkdir -p ${FUNCTION_DIR}

# Update pip
RUN pip install -U pip wheel six setuptools

# Install the function's dependencies
RUN pip install \
    --target ${FUNCTION_DIR} \
        awslambdaric \
        boto3 \
        redis \
        httplib2 \
        requests \
        numpy \
        scipy \
        pandas \
        pika \
        kafka-python \
        cloudpickle \
        ps-mem \
        tblib \
        delegator.py


FROM python:3.8-buster

# Include global arg in this stage of the build
ARG FUNCTION_DIR
# Set working directory to function root directory
WORKDIR ${FUNCTION_DIR}

# Copy in the built dependencies
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}

# Add Lithops
COPY lithops_lambda.zip ${FUNCTION_DIR}
RUN unzip lithops_lambda.zip \
    && rm lithops_lambda.zip \
    && mkdir handler \
    && touch handler/__init__.py \
    && mv entry_point.py handler/

# Put your dependencies/tools here, using RUN pip install... or RUN apt install...


# install go
RUN wget https://go.dev/dl/go1.19.3.linux-amd64.tar.gz
RUN tar -xvf go1.19.3.linux-amd64.tar.gz
RUN rm go1.19.3.linux-amd64.tar.gz
RUN mv go /usr/local

# ENV for Go
ENV GOROOT="/usr/local/go"
ENV PATH="${PATH}:${GOROOT}/bin"
ENV PATH="${PATH}:${GOPATH}/bin"
ENV GOPATH=$HOME/go

RUN GO111MODULE=on go install github.com/jaeles-project/gospider@latest

RUN go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

RUN go install github.com/d3mondev/puredns/v2@latest

RUN go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

RUN go install github.com/hahwul/dalfox/v2@latest

COPY nuclei .

RUN go install -v github.com/ffuf/ffuf@latest

RUN go install -v github.com/tomnomnom/fff@latest

RUN GO111MODULE=on go install github.com/jaeles-project/jaeles@latest

RUN /go/bin/jaeles config init

RUN git clone https://github.com/projectdiscovery/nuclei-templates.git /nuclei-templates

RUN git clone https://github.com/0xjbb/static-nmap.git /static-nmap && chmod +x /static-nmap/nmap

RUN git clone https://github.com/robertdavidgraham/masscan /masscan && cd /masscan && make

RUN curl -LO https://github.com/assetnote/kiterunner/releases/download/v1.0.2/kiterunner_1.0.2_linux_amd64.tar.gz && tar xvf kiterunner_1.0.2_linux_amd64.tar.gz

RUN  curl -o /function/resolvers.txt -LO https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt

COPY ./massdns /usr/local/bin/massdns

# install massdns
RUN git clone https://github.com/blechschmidt/massdns.git
RUN cd massdns && make && cp bin/massdns /usr/local/bin/massdns


ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
CMD [ "handler.entry_point.lambda_handler" ]

