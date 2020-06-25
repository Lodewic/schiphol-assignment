import pandas as pd

from .metrics import get_regression_metrics


def get_regression_df(yhat, y, list_metrics=None):
    # return regression dictionary as single-row dataframe
    metrics_dict = get_regression_metrics(yhat, y, list_metrics=list_metrics)
    metrics_dict["n"] = len(yhat)
    metrics_df = pd.DataFrame(metrics_dict, index=[0]).reset_index(drop=True)
    return metrics_df


def make_regression_metrics_by_group(df_predictions,
                                     group_cols = ["model_set", "schedule_date"],
                                     list_metrics = ["mae", "mape","rmse"]):

    # calculate regression metrics by group
    df_metrics = df_predictions \
        .groupby(group_cols) \
        .apply(lambda x: get_regression_df(x["yhat"], x["y"], list_metrics=list_metrics)) \
        .reset_index()
    
    # drop unwanted columns as temp bugfix
    df_metrics = df_metrics[[x for x in df_metrics.columns 
                                 if not x.startswith("level_")
                                 or x.startswith("Unnamed: ")]]

    # convert metrics to long-format
    metric_cols = [x for x in df_metrics.columns 
                       if x in list_metrics + group_cols]
    df_metrics_long = df_metrics.melt(id_vars=group_cols)
    
    return df_metrics_long

def make_regression_metrics_by_datetime(df_predictions,
                                        freq = "H",
                                        alias = None,
                                        group_cols = ["model_set"], 
                                        list_metrics = ["mae", "mape", "rmse"]):
    """
    https://pandas.pydata.org/pandas-docs/stable/user_guide/timeseries.html#timeseries-offset-aliases
    """
    if alias is None:
        dt_freq_col = f"datetime_{freq}"
    else:
        dt_freq_col = alias
        
    # convert schedule datetime to date frequency toa aggregate by
    if freq in ["D", "H", "T", "min", "S"]:
        # a day or lower frequency we can floor
        df_predictions[f"{dt_freq_col}"] = pd.to_datetime(df_predictions["scheduleDateTime"], utc=True) \
                                            .dt.floor(freq)
    else:
        # higher frequencies like weeks or months cant be floored
        df_predictions[f"{dt_freq_col}"] = pd.to_datetime(df["scheduleDateTime"], utc=True) \
                                            .dt.to_period(freq).dt.to_timestamp()
    
    # create regression dataframe with group_cols and additional date frequency
    df_metrics_long = make_regression_metrics_by_group(
                        df_predictions, group_cols = group_cols + [dt_freq_col])
    
    return df_metrics_long