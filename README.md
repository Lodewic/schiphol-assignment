Schiphol-Code-Assignment
==============================

Project summary and results on readthedocs.

Docs: https://schiphol-assignment.readthedocs.io/en/latest/

[![Documentation Status](https://readthedocs.org/projects/schiphol-assignment/badge/?version=latest)](https://schiphol-assignment.readthedocs.io/en/latest/?badge=latest)

Code assignment for Schiphol position

## Local environment setup

For local development we use multiple conda environments because they play nice with `papermill` without having to deal with conflicts between packages as much.

```
conda env create -f ./envs/schiphol-snakemake.yml
conda env create -f ./envs/schiphol-py.yml
conda env create -f ./envs/schiphol-r.yml
conda env create -f ./envs/schiphol-tf.yml

conda deactivate
conda activate schiphol-snakemake
python -m ipykernel install --user --name schiphol-snakemake --display-name "Python (schiphol-snakemake)"
conda deactivate

conda deactivate
conda activate schiphol-py
python -m ipykernel install --user --name schiphol-py --display-name "Python (schiphol-py)"
conda deactivate

conda deactivate
conda activate schiphol-r
python -m ipykernel install --user --name schiphol-r --display-name "Python (schiphol-r)"
conda deactivate

conda deactivate
conda activate schiphol-tf
python -m ipykernel install --user --name schiphol-tf --display-name "Python (schiphol-tf)"
conda deactivate
```

## Docker setup

The whole workflow is designed to work in a docker container so that we can deploy it on a larger machine in the future.
This also allows us to test whether development on Windows caused any issues, which I can tell it definitely did.

Look at the Dockerfile for the steps to setup your own local environment similarly.

### Build container

```
docker build -t schiphol .
```

### Run container

To run the Snakemake pipeline you will need write-access to the storage bucket. Unless mistakes were made you will not find the credentials here,
so ask them from me (Lodewic) if you want to run it.

The container itself contains none of the pipeline code, only its dependencies. The result is that we only need to rebuild the container if any of the
conda dependencies change, otherwise the container is static. So run our own code we mount the whole directory instead,

Note, this will run the whole pipeline depending on your local `./snakemake` directory which contains any metadata of your last pipeline run. Because this
folder is .gitignored you'll find that each new machine considers all files outdated and therefore re-runs the whole pipeline always. That is why, for production, 
this container would run on a container in the cloud where the `./snakemake` folder is used as the ground-truth of the pipeline state. When changes are made to the code,
we would have to push the code to this VM.

```
docker run ${pwd}:/project schiphol
```

Or if you want to control the commands yourself, get in there with bash,

```
docker run ${pwd}:/project -it schiphol bash
```


## Connecting to Google cloud storage

Connect to Google cloud storage so that we can create a key for the service-account that has access to the
Google cloud storage buckets. You can create a key either from the [GCP console](https://console.cloud.google.com/) or through the command line.

### Console

TODO

### Command line

To use the command line, first [install the Google cloud SDK](https://cloud.google.com/sdk/docs/#install_the_latest_cloud_tools_version_cloudsdk_current_version) so that you can use `gcloud` commands.

Make sure the right account is activated, one way to do so is just logging in again.
Then also set the active project, just to be sure.

Then, if you don't have one already, create a service-account key and save it to `keys/bucket-access.json`. Using the same name for the .json file
ensures that our code will run the same for everyone.

```
conda activate schiphol-snakemake
gcloud auth login
gcloud config set project schiphol-assignment
gcloud iam service-accounts keys create keys/bucket-access.json --iam-account bucket-acces@schiphol-assignment.iam.gserviceaccount.com
```


Project Organization
------------


    ├── README.md          <- The top-level README for developers using this project.
    ├───scripts            <- All papermill notebooks that serve as scripts, each with an associated rule in the Snakefile
    ├───data               <- Local data folder in case cloud-storage not available. Only for local development use
    │   ├───external
    │   ├───interim
    │   ├───processed
    │   └───raw
    ├───docs               <- Sphinx project iuncluding nbsphinx extension to include all notebooks under `/scripts`
    │   ├───figures        <- static figures to include in documentation page
    │   ├───scripts        <- Copy of `/scripts` with pre-rendered notebooks
    │   ├───_build
    │   └───_static
    ├───envs
    ├───keys               <- in .gitignore but save your credentials to mlflow and gcp here. Snakemake expects credentials at keys/bucket-access.json, ask Lodewic for keys.
    ├───lvt-schiphol-assignment-snakemake    <- Local sync of the cloud-storage bucket, in .gitignore but automatically created when running Snakemake
    │   ├───data
    │   │   ├───model_input
    │   │   │   ├───features
    │   │   │   └───targets
    │   │   ├───model_output
    │   │   │   ├───baseline_average__0.2__sample
    │   │   │   ├───baseline_average__0.2__timeseries
    │   │   │   ├───catboost_simple__0.2__sample
    │   │   │   └───catboost_simple__0.2__timeseries
    │   │   └───raw
    │   ├───mlruns
    │   ├───reports
    │   │   └───profiling_reports
    │   └───trelliscopes
    │
    │───models
    ├───notebooks            <- Exploratory notebooks. These are not maintained nor expected to be runnable(!)
    ├───references           <- Assignment pdf, data dictionaries, manuals, and all other explanatory materials.
    ├───reports              <- Local reports as HTML, PDF, LaTeX, etc.
    ├───src                  <- Source code for use in this project.
    │   ├───data
    │   ├───evaluation       <- Model performance evaluation utilities
    │   ├───models
    │   ├───pipelines
    │   ├───transformers
    │
    ├───Snakefile            <- Snakemake pipeline definition including all rules and target files
    ├───config.yaml          <- Snakemake config file to set cloud storage bucket and rule parameters
    └── tox.ini              <- tox file with settings for running tox; see tox.readthedocs.io

--------
