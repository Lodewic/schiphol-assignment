# standard
import numpy as np

# sklearn
from sklearn.base import BaseEstimator, TransformerMixin


class categoryImputer(BaseEstimator, TransformerMixin):
    
    def __init__(self, category_columns, missing_values=np.nan:
        self._category_columns = category_columns
        
        self._imputer = SimpleImputer(missing_values=missing_values,
                                      strategy="constant",
                                      fill_value="missing")
        
    @property 
    def category_columns(self):
        return self._category_columns
            
    @property
    def imputer(self):
        return self._imputer
    
    def fit(self, X, y=None):
        X_imputed = self.imputer.fit(X[self.category_columns])
        return self
        
    def transform(self, X, y=None):
        X_imputed = self.imputer.transform(X[self.category_columns])
        X[self.category_columns] = X_imputed
        return X
        