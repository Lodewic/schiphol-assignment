"""
Utility functions for file IO from google storage

main functions
- load_data:  reads CSV file to DataFrame from GS or locally, automatically determined
- download_csv_from_bucket:    reads CSV file to DataFrame and saves a local copy
- write_csv_to_bucket: save CSV file to GS bucket
"""


import os
import pandas as pd
from google.cloud import storage
from io import StringIO # if going with no saving csv file
from pathlib import Path, PurePosixPath

### utility functions ###
def _read_file(blob, format):
        """Reads a non-notebook file.

        blob: instance of :class:`google.cloud.storage.Blob`.
        format:
          If "text", the contents will be decoded as UTF-8.
          If "base64", the raw bytes contents will be encoded as base64.
          If not specified, try to decode as UTF-8, and fall back to base64
          
        Taken from https://www.programcreek.com/python/example/104465/google.cloud.storage.Blob
        """
        bcontent = blob.download_as_string()

        if format is None or format == "text":
            # Try to interpret as unicode if format is unknown or if unicode
            # was explicitly requested.
            try:
                return bcontent.decode("utf8"), "text"
            except UnicodeError:
                if format == "text":
                    raise web.HTTPError(
                        400, "%s is not UTF-8 encoded" %
                             self._get_blob_path(blob),
                        reason="bad format",
                    )
        return base64.encodebytes(bcontent).decode("ascii"), "base64" 

def file_is_on_gs(filename):
    file_location = "gs" if filename.startswith("gs://") else "local"
    return file_location == "gs"


def split_gs_filename(filename):
    filename_no_gs = filename.replace("gs://", "")
    bucket = Path(filename_no_gs).parts[0]
    filepath = str(PurePosixPath(*Path(filename_no_gs).parts[1:]))
    
    return bucket, filepath


def set_credentials(credentials):
    """
    Set environment variable for credentials .json file
    
    accepts None for ease of use
    """
    if credentials is not None:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.path.abspath(credentials)

        
### read/write functions for google storage bucket ###
def download_csv_from_bucket(filename, destination_file_name, credentials=None):
    """Downloads a blob from the bucket to local file"""
#     set_credentials(credentials)
    bucket_name, filepath = split_gs_filename(filename)
    
    storage_client = storage.Client.create_anonymous_client()
    bucket = storage_client.bucket(bucket_name=bucket_name)
    blob = bucket.blob(filepath)

    if not os.path.isdir(os.path.dirname(destination_file_name)):
        os.makedirs(os.path.dirname(destination_file_name))
        
    blob.download_to_filename(destination_file_name)

    print(f'Blob {filename} downloaded to {destination_file_name}')
    
    
def read_csv_from_bucket(filename, credentials=None, verbose=True, **kwargs):
    """Reads a blob from the bucket and loads it as pandas DataFrame without saving locally"""
#     set_credentials(credentials)
    bucket_name, filepath = split_gs_filename(filename)

    if verbose:
        print("Reading file from Google Storage\n"
                  f"Bucket:\t{bucket_name}\n"
                  f"File:\t{filepath}\n")
    
    storage_client = storage.Client.create_anonymous_client()
    bucket = storage_client.bucket(bucket_name=bucket_name)
    blob = bucket.blob(filepath)
    blob_content, _ = _read_file(blob, format=None)
    return pd.read_csv(StringIO(blob_content), **kwargs)


def write_csv_to_bucket(df, filename, credentials=None, verbose=True, **kwargs):
    """Writes a DataFrame to the bucket without intermediate file"""
    set_credentials(credentials)
    bucket_name, filepath = split_gs_filename(filename)
        
    if verbose:
        print("Writing file to Google Storage\n"
                  f"Bucket:\t{bucket_name}\n"
                  f"File:\t{filepath}\n")
        
    # Use StringIO() to avoid writing to intermediate file
    f = StringIO()
    df.to_csv(f)
    f.seek(0)
    
    ## TODO: use pd.to_csv("gs://<filename>") instead, currently not 
    ## working with non-default service account for bucket
    # Write directly to file in bucket on GS
    storage.Client() \
        .storage_client.bucket(bucket_name=bucket_name) \
        .blob(filepath) \
        .upload_from_file(f, content_type='text/csv')

    return True


### main read/write functions that work for both local and GS ###
def read_csv_data(filename, credentials=None, verbose=True, **kwargs):
    """
    Load data from file either on Google Storage or locally into a DataFrame
    
    Determines whether file is on Google Storage by checking if filename starts with 'gs://'
    """    
    # if on GS split bucket name from file location as first directory
    if file_is_on_gs(filename):
        df = read_csv_from_bucket(filename, credentials=credentials, verbose=verbose, **kwargs)
    else:
        if verbose:
            print("Reading file from local directory\n"
                  f"File:\t{filename}\n")
            
        df = pd.read_csv(filename, **kwargs)
    
    return df


def write_csv_data(df, filename, credentials=None, verbose=True, **kwargs):
    """
    Load data from file either on Google Storage or locally into a DataFrame
    
    Determines whether file is on Google Storage by checking if filename starts with 'gs://'
    """
    # if on GS split bucket name from file location as first directory
    if file_is_on_gs(filename):
        write_csv_to_bucket(df, filename, credentials=credentials, verbose=verbose, **kwargs)
    else:
        if verbose:
            print("Writing file to local directory\n"
                  f"File:\t{filename}\n")
            
        df = df.to_csv(filename, **kwargs)
    
    return df


