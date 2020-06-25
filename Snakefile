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
    	# profiling_reports,
    	# Remote(f"{BUCKET}/data/model_input/features/route_destinations.csv"),
    	# Remote(f"{BUCKET}/data/model_input/delays_base_input.csv"),
    	# Remote(f"{BUCKET}/data/model_input/features/schedule_time_features.csv")
    	# Remote(f"{BUCKET}/data/model_input/delays_extended_input.csv"),
    	# train_test_sets,
    	# model_predictions,
    	# Remote(f"{BUCKET}/data/model_input/features/rolling_mean_delay__10T__1D+1H+2H+6H.csv"),
    	"docs/_build/html/index.html"


rule flights:
	output:
		Remote(f"{BUCKET}/data/raw/flights.csv")

rule airports:
	output:
		Remote(f"{BUCKET}/data/raw/airports.csv")

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
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p train_test_file \"{input.train_test}\" "
		"-p output_predictions \"{output.predictions}\""


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
	params:
		env="schiphol-py"
	shell: 
		"papermill {input.notebook} \"{log.notebook}\" "
		"-k {params.env} --inject-paths "
		"-p input_file \"{input.data}\" "
		"-p train_test_file \"{input.train_test}\" "
		"-p output_predictions \"{output.predictions}\""

rule move_script_to_docs:
	input:
		"scripts/{file}.ipynb"
	output:
		"docs/{file}.ipynb"
	shell:
		"mv {input} {output}"

rule make_docs:
	input:
		"docs/index.rst",
		"docs/conf.py",
		"docs/explore__pandas_profiling.ipynb",
		"docs/model__catboost_simple.ipynb"
	output:
		"docs/_build/html/index.html",
	shell:
		"cd docs && make html"
