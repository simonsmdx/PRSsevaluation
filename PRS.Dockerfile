FROM ubuntu:20.04

WORKDIR app/
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends build-essential pandoc gawk r-base r-cran-randomforest git libpq-dev python3.8 python3-pip python3-setuptools python3-dev

ADD requirements.txt .
ADD requirements.R .
RUN pip3 install -r requirements.txt
RUN Rscript requirements.R

WORKDIR /usr/local/
RUN git clone https://github.com/smntest00/PRSsevaluation

RUN apt-get install -y unzip wget && \
    wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20220402.zip && \
    unzip plink_linux_x86_64_20220402.zip 

ARG add='$@'
RUN printf "!/bin/bash\n\n  ./plink $add \n" > /usr/local/bin/plink
RUN chmod a+rx /usr/local/bin/plink

# install dependencies, cleanup apt garbage
RUN apt-get update && apt-get install --no-install-recommends -y \
 wget \
 ca-certificates \
 perl \
 bzip2 \
 autoconf \
 automake \
 make \
 gcc \
 zlib1g-dev \
 libbz2-dev \
 liblzma-dev \
 libcurl4-gnutls-dev \
 libssl-dev \
 libperl-dev \
 libgsl0-dev && \
 rm -rf /var/lib/apt/lists/* && apt-get autoclean
ARG bcftoolsVer="1.12"
# get bcftools 
RUN wget https://github.com/samtools/bcftools/releases/download/${bcftoolsVer}/bcftools-${bcftoolsVer}.tar.bz2 && \
 tar -vxjf bcftools-${bcftoolsVer}.tar.bz2 && \
 rm bcftools-${bcftoolsVer}.tar.bz2 && \
 cd bcftools-${bcftoolsVer} && \
 make && \
 make install

RUN Rscript -e 'install.packages("plotly")'
RUN chmod +x /usr/local/PRSsevaluation/prs_pipe.sh
WORKDIR /usr/local/PRSsevaluation
ENTRYPOINT []
