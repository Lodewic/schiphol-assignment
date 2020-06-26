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
	"""Set `file` to remote `provider` if config['remote'] is true"""
	if config['remote'] is True:
		file = GS.remote(file)
	return file

def make_files_remote(files, provider=GS):
	"""Set list of files to remotes"""

	if isinstance(files, list):
		remotes = [Remote(x, provider=provider) for x in files]
	else:
		remotes = Remote(files, provider=provider)
	
	return remotes


def basename_noext(filename):
	"""get filename without extension from filepath"""
	base = os.path.basename(filename)
	base_noext = os.path.splitext(base)[0]
	return base_noext

### Define target files ###
# We have to create all the filenames that we want to create.
# Snakemake will find out how to create files that don't exist, using the
# rules defined further down below. Files will be created if,
# - the file doesn't exist
# - upstream files that are an input to the rule that creates the file are updated
# - the timestamp of a file is more recent than the last Snakemake run, indicating
# manual changes
#
# All files that are added to the 'all' rule will be created when calling
# `snakemake --cores` from the cli.

BUCKET = config['gcloud']['bucket']
profiling_reports = expand("{bucket}/reports/profiling_reports/{table_name}.html",
							bucket=BUCKET,
			    			table_name=[basename_noext(x) for x in config['raw_files']])
profiling_reports = make_files_remote(profiling_reports)

train_test_sets = expand("{bucket}/data/model_input/train_test__{test_size}__{strategy}.csv",
						 bucket = BUCKET,
						 test_size = config['train_test']['test_size'],
						 strategy = config['train_test']['strategy'])
train_test_sets = make_files_remote(train_test_sets)


model_predictions = expand("{bucket}/data/model_output/{model}__{test_size}__{strategy}/predictions.csv",
							bucket = BUCKET,
							model = config['models'],
							test_size = config['train_test']['test_size'],
							strategy = config['train_test']['strategy'])
model_predictions = make_files_remote(model_predictions)


# TRELLISCOPE RULE BROKEN - MUST RUN IT MANUALLY :(
trelliscope_displays = [
	f"{BUCKET}/{config['trelliscope']['path']}/appfiles/displays/common/Delays_Type_Airline/displayObj.jsonp",
	f"{BUCKET}/{config['trelliscope']['path']}/appfiles/displays/common/Delays_Type_Airline/displayObj.jsonp"]
trelliscope_displays = make_files_remote(trelliscope_displays)                                                    


# the 'all' rule defines only the target files that you want to generate - as input the the 'all' rule
## Comment out files that you want to ignore or add those you want to create
rule all:
    input:
    	profiling_reports,
    	model_predictions,
    	Remote(f"{BUCKET}/data/model_input/features/rolling_mean_delay__10T__1D+1H+2H+6H.csv"),
    	"docs/_build/html/index.html"

### Dummies for raw data check ###

rule flights:
	output:
		Remote(f"{BUCKET}/data/raw/flights.csv")

rule airports:
	output:
		Remote(f"{BUCKET}/data/raw/airports.csv")

### Data exploration

rule create_pandas_profiling:
	input:
		data=Remote("{bucket}/data/raw/{table_name}.csv"),
		notebook="scripts/explore__pandas_profiling.ipynb"
	output: 
		html_report=Remote(report("{bucket}/reports/profiling_reports/{table_name}.html",
									category="pandas_profiling"))
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
		"-p profiling_config \"scripts/profiling_config.yml\""

### Create base model input ###

rule preprocess__base_model_input:
	input:
		data=Remote("{bucket}/data/raw/flights.csv"),
		notebook="scripts/preprocess__base_model_input.ipynb"
	output: 
		data=Remote("{bucket}/data/model_input/delays_base_input.csv")
	log:
		notebook=report(Remote("{bucket}/data/model_input/preprocess__base_model_input.ipynb"),
							category="logs")
	params:
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p output_file \"{output.data}\" "

### Features ###

rule feature__route_destinations:
	input:
		flights=Remote("{bucket}/data/raw/flights.csv"),
		airports=Remote("{bucket}/data/raw/airports.csv"),
		notebook="scripts/feature__route_destinations.ipynb"
	output: 
		data=Remote("{bucket}/data/model_input/features/route_destinations.csv")
	log:
		notebook=report(Remote("{bucket}/data/model_input/features/feature__route_destinations.ipynb"),
							category="logs")
	params:
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p flights_file \"{input.flights}\" "
		"-p airports_file \"{input.airports}\" "
		"-p output_file \"{output.data}\" "


rule feature__schedule_time_features:
	input:
		data=Remote("{bucket}/data//raw/flights.csv"),
		notebook="scripts/feature__time_features_from_datetime.ipynb"
	output: 
		data=Remote("{bucket}/data/model_input/features/schedule_time_features.csv")
	log:
		notebook=report(Remote("{bucket}/data/model_input/features/feature__time_features_from_datetime.ipynb"),
							category="logs")
	params:
		env="schiphol-py",
		dt_column="scheduleDateTime",
		id_column="id"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p output_file \"{output.data}\" "
		"-p dt_column \"{params.dt_column}\" "
		"-p id_column \"{params.id_column}\" "


rule feature__rolling_mean_delay:
	input:
		data=Remote("{bucket}/data/model_input/delays_base_input.csv"),
		notebook="scripts/feature__rolling_mean_delay.ipynb"
	output: 
		data=Remote("{bucket}/data/model_input/features/rolling_mean_delay__{freq}__{window}.csv")
	log:
		notebook=report(Remote("{bucket}/data/model_input/features/feature__rolling_mean_delay__{freq}__{window}.ipynb"),
							category="logs")
	params:
		env="schiphol-py",
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p output_file \"{output.data}\" "
		"-p freq \"{wildcards.freq}\" "
		"-p window \"{wildcards.window}\" "



rule preprocess__extend_base_with_features:
	input:
		base = Remote("{bucket}/data/model_input/delays_base_input.csv"),
		time_features = Remote("{bucket}/data/model_input/features/schedule_time_features.csv"),
		route_features = Remote("{bucket}/data/model_input/features/route_destinations.csv"),
		notebook = "scripts/preprocess__extend_base_with_features.ipynb"
	output: 
		data=Remote("{bucket}/data/model_input/delays_extended_input.csv")
	log:
		notebook=report(Remote("{bucket}/data/model_input/features/feature__time_features_from_datetime.ipynb"),
							category="logs")
	params:
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p base_file \"{input.base}\" "
		"-p features \"{input.time_features}+{input.route_features}\" "
		"-p output_file \"{output.data}\" "


rule train_test_split:
	input:
		data = Remote("{bucket}/data/model_input/delays_base_input.csv"),
		notebook = "scripts/preprocess__train_test_split.ipynb"
	output:
		data = Remote("{bucket}/data/model_input/train_test__{test_size}__{strategy}.csv")
	log:
		notebook = report(Remote("{bucket}/data/model_input/preprocess__train_test_split_{test_size}__{strategy}.ipynb"),
								category="logs")
	params:
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p output_file \"{output.data}\" "
		"-p test_size {wildcards.test_size} "
		"-p strategy {wildcards.strategy} "


### Prediction models ###

rule model__baseline_average:
	input:
		data = Remote("{bucket}/data/model_input/delays_extended_input.csv"),
		train_test = Remote("{bucket}/data/model_input/train_test__{test_size}__{strategy}.csv"),
		notebook = "scripts/model__baseline_average.ipynb"
	output:
		predictions = Remote("{bucket}/data/model_output/baseline_average__{test_size}__{strategy}/predictions.csv")
	log:
		notebook = report(Remote("{bucket}/data/model_output/baseline_average__{test_size}__{strategy}/model__baseline_average.ipynb"),
								category="logs")
	params:
		env="schiphol-py",
		mlflow_experiment = config["mlflow"]["experiment"],
		mlflow_uri = config["mlflow"]["tracking_uri"],
		mlflow_run = "catboost_simple__{test_size}_{strategy}"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p train_test_file \"{input.train_test}\" "
		"-p output_predictions \"{output.predictions}\" "
		"-p mlflow_tracking_uri \"{params.mlflow_uri}\" "
		"-p mlflow_experiment \"{params.mlflow_experiment}\" "
		"-p mlflow_run \"{params.mlflow_run}\" "



rule model__catboost_simple:
	input:
		data = Remote("{bucket}/data/model_input/delays_extended_input.csv"),
		train_test = Remote("{bucket}/data/model_input/train_test__{test_size}__{strategy}.csv"),
		notebook = "scripts/model__catboost_simple.ipynb"
	output:
		predictions = Remote("{bucket}/data/model_output/catboost_simple__{test_size}__{strategy}/predictions.csv")
	log:
		notebook = report(Remote("{bucket}/data/model_output/catboost_simple__{test_size}__{strategy}/model__catboost_simple.ipynb"),
								category="logs")
	threads: 8
	params:
		env="schiphol-py",
		mlflow_experiment = config["mlflow"]["experiment"],
		mlflow_uri = config["mlflow"]["tracking_uri"],
		mlflow_run = "catboost_simple__{test_size}_{strategy}"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p train_test_file \"{input.train_test}\" "
		"-p output_predictions \"{output.predictions}\" "
		"-p mlflow_tracking_uri \"{params.mlflow_uri}\" "
		"-p mlflow_experiment \"{params.mlflow_experiment}\" "
		"-p mlflow_run \"{params.mlflow_run}\" "


## TODO: HOW TO OUTPUT DIRECTORY TO REMOTE??? CAN'T USE DIRECTORY AS INPUT..
### Currently broken because or irkernel + papermill bug
rule r__raw_trelliscope:
	input:
		flights = Remote("{bucket}/data/raw/flights.csv"),
		airports = Remote("{bucket}/data/raw/airports.csv"),
		notebook = "scripts/r-explore__create_trelliscopes.ipynb"
	output:
		obj1 = Remote("{bucket}/{dir}/appfiles/displays/common/Delays_Type_Airline/displayObj.jsonp"),
		obj2 = Remote("{bucket}/{dir}/appfiles/displays/common/Number_of_flights_per_day/displayObj.jsonp"),
		# display1 = Remote(directory("{bucket}/{dir}/appfiles/displays/common/Delays_Type_Airline/")),        
		# display2 = Remote(directory("{bucket}/{dir}/appfiles/displays/common/Number_of_flights_per_day/"))
	log:
		notebook = Remote("{bucket}/{dir}/r-explore__create_trelliscopes.ipynb")
	params:
		env = "schiphol-r",
		trelliscope_path = config["trelliscope"]["path"]
	shell: 
		"conda activate {params.env} && "
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k \"ir\" --inject-paths "
		"-p input_flights \"{input.flights}\" "
		"-p input_airports \"{input.airports}\" "
		"-p output_path \"{wildcards.bucket}/{wildcards.dir}\" && "
		"conda deactivate"


### Sphinx Docs ###

rule move_script_to_docs:
	input:
		"scripts/{file}.ipynb"
	output:
		"docs/{file}.ipynb"
	shell:
		"cp {input} {output}"

rule make_docs:
	input:
		"docs/index.rst",
		"docs/conf.py"
	output:
		"docs/_build/html/index.html",
	shell:
		"cd docs && make html"