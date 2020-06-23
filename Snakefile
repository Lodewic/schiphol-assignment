import os
from pathlib import Path
from snakemake.remote.GS import RemoteProvider as GSRemoteProvider

# Read values from config.yaml. Available in variable `config` as dictionary values
configfile: "config.yaml"

# Google cloud storage connection
GS_CREDENTIALS = str(Path(os.path.join(os.getcwd(), config['gcloud']['credentials'])))
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = GS_CREDENTIALS

GS = GSRemoteProvider(stay_on_remote=False, keep_local=True)

def Remote(file, provider=GS):
	if config['remote'] is True:
		file = GS.remote(file)
	return file

def make_files_remote(files, provider=GS):
	if isinstance(files, list):
		remotes = [Remote(x) for x in files]
	else:
		remotes = Remote(files)
	return remotes


def basename_noext(filename):
	base = os.path.basename(filename)
	base_noext = os.path.splitext(base)[0]
	return base_noext

# TARGET FILES
profiling_reports = expand("{bucket}/reports/profiling_reports/{table_name}.html",
							bucket="gs://" + config['gcloud']['bucket'],
			    			table_name=[basename_noext(x) for x in config['raw_files']])
profiling_reports = make_files_remote(profiling_reports)

# the 'all' rule defines only the target files that you want to generate - as input the the 'all' rule
## Comment out files that you want to ignore
rule all:
    input:
    	profiling_reports


# rule preprocess_flights:
# 	input:
# 		data=GS("{bucket}/raw/{table_name}.csv"),
# 		notebook="scripts/explore__pandas_profiling.ipynb"
# 	output:
# 		html_report=report(GS("{bucket}/reports/profiling_reports/{table_name}.html",
# 			category="pandas_profiling"))
# 	log:
# 		notebook=report(GS("{bucket}/reports/profiling_reports/{table_name}__explore__pandas_profiling.ipynb"
# 			category="logs"))
# 	params:
# 		env="schiphol-py"
# 	shell: 
# 		"papermill {input.notebook} \"{log.notebook}\" "
# 		"-k {params.env} --inject-paths "
# 		"-p input_file \"{input.data}\" "
# 		"-p output_file \"{output.html_report}\" "


rule create_pandas_profiling:
	input:
		data=Remote("{bucket}/data/raw/{table_name}.csv"),
		notebook="scripts/explore__pandas_profiling.ipynb"
	output: 
		html_report=report(Remote("{bucket}/reports/profiling_reports/{table_name}.html"),
								category="pandas_profiling")
	log:
		notebook=report(Remote("{bucket}/reports/profiling_reports/{table_name}__explore__pandas_profiling.ipynb"),
							category="logs")
	params:
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p output_file \"{output.html_report}\" "
