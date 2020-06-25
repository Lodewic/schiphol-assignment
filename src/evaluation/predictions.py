import pandas as pd

def make_predictions_dataframe(model,
                               X_train, X_test,
                               y_train, y_test,
                               X_val = None, y_val = None,
                               meta_train = None,
                               meta_test = None
                              ):
    preds_train = model.predict(X_train) 
    preds_test = model.predict(X_test)
    
    if meta_train is None:
        meta_train = X_train[["id", "scheduleDateTime"]]
    
    df_preds_train = meta_train \
        .assign(
            y = y_train,
            yhat = preds_train,
            error = preds_train - y_train,
            model_set = "train")
    
    if meta_test is None:
        meta_test = X_test[["id", "scheduleDateTime"]]
        
    df_preds_test = meta_test \
        .assign(
            y = y_test,
            yhat = preds_test,
            error = preds_test - y_test,
            model_set = "test")
    
    df_preds = pd.concat([df_preds_train, df_preds_test])
    return df_preds
