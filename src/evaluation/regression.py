import sklearn.metrics
import numpy as np
import numpy as np
np.seterr(divide='ignore', invalid='ignore')

allowed_metrics = [
    "mae","mse","rmse", "mape",
    "median_absolute_error","max_error","explained_variance",
    "r2_score",
    "wce"  # weighted cumulative error
    ]
"""
This scripts contains some simple metrics to evaluate 
the performance of the prediction during a race.

If not stated otherwise, the functions take in input
the list of prediction errors during a single race.
"""

def mean_absolute_percentage_error(y_true, y_pred): 
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    return np.mean(np.abs((y_true - y_pred) / y_true)) * 100

def weighted_cumulative_error(errors, weight_range=(0,1)):
    """
    Sum of the prediction errors in a race,
    linearly weighted in the defined range.
    
    Parameters:
    weight_range (tuple): tuple of two values defining
    the range of the weights for the errors.
    
    Return: scalar value
    """
    
    error_scaling = np.linspace(weight_range[0],weight_range[1],len(errors))
    
    return np.sum(np.abs(errors)*error_scaling)



def get_regression_metrics(y_true, y_pred, list_metrics=None, ignore_zero=False):
    """
    Function to return many different error/score metrics for regression analysis. Returns all available metrics if none are defined.
    
    Allowed values in list_metrics are: ["mae","mse","rmse", "median_absolute_error","max_error","explained_variance","r2_score"]

    Args:
        y_true (np.array): measurements
        y_pred (np.array): predictions
        list_score_metrics (array of str): array with score metrics.
        
    Returns:
        dict, dictionary containing different error metrics for regression analysis
    """
    
    try:
        y_true, y_pred = y_true.values, y_pred.values
    except:
        pass
    
    assert isinstance(list_metrics, list) or (list_metrics == None)
    dict_scores = {}
    if list_metrics is not None:
        for metric in list_metrics:
            try:
                score = get_regression_metric(y_true, y_pred, metric)
                dict_scores[metric] = score
            except:
                print(f"metric {metric} failed")
                pass

    # Get score/metrics over all allowed metrics.
    else:
        for metric in allowed_metrics:
            score = get_regression_metric(y_true, y_pred, metric)
            try:
                score = get_regression_metric(y_true, y_pred, metric)
                dict_scores[metric] = score
            except:
                print(f"metric {metric} failed")
                pass

    return dict_scores


def get_regression_metric(y_true, y_pred, metric=""):
    """
    Function to get regression score.

    Allowed metrics are: ["mae","mse","rmse", "median_absolute_error","max_error","explained_variance","r2_score"]

    Args:
        y_true (np.array): measurements
        y_pred (np.array): predictions
        metric (str): string giving metric to return

    Returns:
        float, error metric for regression analysis

    """

    try:
        assert metric in allowed_metrics
    except AssertionError as e:
        print(e)
    
    if metric == "mape":
        return mean_absolute_percentage_error(y_true, y_pred)
            
    if metric == "wce":
        errors = [x - y for x, y in zip(y_true, y_pred)]
        return weighted_cumulative_error(errors)

    if metric == "mae":
        return sklearn.metrics.mean_absolute_error(y_true, y_pred)
    
    if metric == "mse":
        return sklearn.metrics.mean_squared_error(y_true, y_pred)
    
    if metric == "rmse":
        return np.sqrt(sklearn.metrics.mean_squared_error(y_true, y_pred))

    if metric == "median_absolute_error":
        return sklearn.metrics.median_absolute_error(y_true, y_pred)

    if metric == "max_error":
        return sklearn.metrics.max_error(y_true, y_pred)

    if metric == "explained_variance":
        return sklearn.metrics.explained_variance_score(y_true, y_pred)

    if metric == "r2_score":
        return sklearn.metrics.r2_score(y_true, y_pred)

def error_mean_variance(errors):
    """
    Returns the mean and variance of the errors.
    
    Return: tuple (mean,variance)
    """
    
    return (np.average(errors), np.var(errors))