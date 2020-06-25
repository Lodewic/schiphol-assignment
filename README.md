Schiphol-Code-Assignment
==============================

Docs: https://schiphol-assignment.readthedocs.io/en/latest/

[![Documentation Status](https://readthedocs.org/projects/schiphol-assignment/badge/?version=latest)](https://schiphol-assignment.readthedocs.io/en/latest/?badge=latest)

Code assignment for Schiphol position

## Environment setup

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

    ├── LICENSE
    ├── Makefile           <- Makefile with commands like `make data` or `make train`
    ├── README.md          <- The top-level README for developers using this project.
    ├── data
    │   ├── external       <- Data from third party sources.
    │   ├── interim        <- Intermediate data that has been transformed.
    │   ├── processed      <- The final, canonical data sets for modeling.
    │   └── raw            <- The original, immutable data dump.
    │
    ├── docs               <- A default Sphinx project; see sphinx-doc.org for details
    │
    ├── models             <- Trained and serialized models, model predictions, or model summaries
    │
    ├── notebooks          <- Jupyter notebooks. Naming convention is a number (for ordering),
    │                         the creator's initials, and a short `-` delimited description, e.g.
    │                         `1.0-jqp-initial-data-exploration`.
    │
    ├── references         <- Data dictionaries, manuals, and all other explanatory materials.
    │
    ├── reports            <- Generated analysis as HTML, PDF, LaTeX, etc.
    │   └── figures        <- Generated graphics and figures to be used in reporting
    │
    ├── requirements.txt   <- The requirements file for reproducing the analysis environment, e.g.
    │                         generated with `pip freeze > requirements.txt`
    │
    ├── setup.py           <- makes project pip installable (pip install -e .) so src can be imported
    ├── src                <- Source code for use in this project.
    │   ├── __init__.py    <- Makes src a Python module
    │   │
    │   ├── data           <- Scripts to download or generate data
    │   │   └── make_dataset.py
    │   │
    │   ├── features       <- Scripts to turn raw data into features for modeling
    │   │   └── build_features.py
    │   │
    │   ├── models         <- Scripts to train models and then use trained models to make
    │   │   │                 predictions
    │   │   ├── predict_model.py
    │   │   └── train_model.py
    │   │
    │   └── visualization  <- Scripts to create exploratory and results oriented visualizations
    │       └── visualize.py
    │
    └── tox.ini            <- tox file with settings for running tox; see tox.readthedocs.io


--------

<p><small>Project based on the <a target="_blank" href="https://drivendata.github.io/cookiecutter-data-science/">cookiecutter data science project template</a>. #cookiecutterdatascience</small></p>
