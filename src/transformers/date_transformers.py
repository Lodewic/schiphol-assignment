# sklearn
from sklearn.base import BaseEstimator, TransformerMixin


class scheduleDateTransformer(BaseEstimator, TransformerMixin):
    def __init__(self):
        pass
    
    @property
    def output_columns(self):
        return ["dayOfWeek", "hourOfDay"]
    
    def fit(self, X, y=None):
        return self
    
    def transform(self, X, y=None):
        X["dayOfWeek"] = X["scheduleDateTime"].dt.dayofweek
        X["hourOfDay"] = X["scheduleDateTime"].dt.hour
        
        return X[self.output_columns]
