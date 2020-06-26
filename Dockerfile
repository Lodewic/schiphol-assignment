FROM continuumio/miniconda3
LABEL maintainer="Lodewic van Twillert lodewic.vantwillert@qualogy.com"

WORKDIR /project/

RUN apt-get update && \
    apt-get install -y build-essential

# add dependencies from environment.yml
RUN conda update -n base -c defaults conda && \
 	conda install pip git 

ADD ./envs/ /project/envs/

RUN conda env create -f ./envs/schiphol-snakemake.yml
RUN conda env create -f ./envs/schiphol-py.yml
RUN conda env create -f ./envs/schiphol-r.yml

# activate conda env if user uses interactive session
RUN echo "source activate schiphol-snakemake" > ~/.bashrc
ENV PATH /opt/conda/envs/schiphol-snakemake/bin:$PATH


# Expose environment as valid kernel to use with papermill
RUN ["/bin/bash", "-c", "source activate schiphol-py; \
       conda info; \
       pip install ipywidgets; \
       python -m ipykernel install --user --name schiphol-py; \
       conda clean -tipsy"]
       
RUN ["/bin/bash", "-c", "source activate schiphol-r; \
       conda info; \
       python -m ipykernel install --user --name schiphol-r; \
       conda clean -tipsy"]


# add google-cloud-sdk for snakemake to connect to Google Storage
RUN apt-get install -y curl

ENV CLOUDSDK_INSTALL_DIR /usr/local/gcloud/
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin


## TO RUN CONTAINER YOU MUST MOUNT A VOLUME WITH KEY UNDER /project/keys/bucket-access.json ##
# Key not included in build for security

# Create DAG figure and run Snakemake 
CMD /bin/bash -c "gcloud auth activate-service-account --key-file=/project/keys/bucket-access.json" && \
    /bin/bash -c "ls" && \
    /bin/bash -c "snakemake --dag | dot -Tsvg > /project/figures/dag.svg" && \
    /bin/bash -c "snakemake" && \
    /bin/bash -c "snakemake --report reports/report.html"
