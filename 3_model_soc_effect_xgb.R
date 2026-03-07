# Load package
library("iterators")
library("foreach")
library("dplyr")
library("doParallel")
library("xgboost")
library("lattice")
library("caret")
library("data.table")

# Load training data ####
train.data <- fread("./input/soc_effects.csv")
train_matrix <- as.matrix(train.data[, c(10:45)])

model_dir  <- "./output/soc_effect/bootstrap_models"
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)

# Build tuning grid
xgb.tuneGrid <- expand.grid(eta = c(0.001, 0.003, 0.005, 0.01, 0.03, 0.05),  
                            nrounds = seq(50, 500, by = 50),        
                            max_depth = c(2:5),                    
                            min_child_weight = c(8:12),       
                            gamma = 0,
                            colsample_bytree = c(0.9),
                            subsample=  c(0.9))

ctrl <- trainControl(method = "cv", number = 10, allowParallel = TRUE, savePredictions = "final")

# Train model of turnover time ####
set.seed(7)
registerDoParallel(96)

model_effect_flux <- train(x = train.data[, c(10:45)],
                           y = train.data$shap_flux,
                           method = "xgbTree",
                           tuneGrid = xgb.tuneGrid,
                           trControl = ctrl)

# Save models as 
saveRDS(model_effect_flux, "./output/soc_effect/model_effect_flux_caret.rds")

# Observed-Predicted 
pred_ob_flux <- data.frame(train.data[, 2:3],
                           Observed = train.data$shap_flux,
                           Predicted = predict(model_effect_flux$finalModel, as.matrix(train.data[, 10:45]), 
                                               na.action = na.pass)) %>%
  mutate(Residual = Observed - Predicted)

write.csv(pred_ob_flux, "./output/soc_effect/pred_ob_flux.csv")

# Bootstrap training models 
train_labels <- train.data$shap_flux
bt <- model_effect_flux$bestTune
model_paths <- file.path(model_dir, sprintf("bootstrap_model_flux_%03d.xgb", 1:100))

if (all(file.exists(model_paths))) {
  cat("models have been trained，skip training. \n")
} else {
  cat("traingin 100 bootstrap modles...\n")
  
  registerDoParallel(96)
  
  foreach(i = 1:100, .packages = "xgboost", .export = c("train_matrix","train_labels","bt","model_paths")) %dopar% {
            set.seed(7 + i)
            idx <- sample(nrow(train_matrix), nrow(train_matrix), replace = TRUE)
            dtrain <- xgb.DMatrix(data = train_matrix[idx, ], label = train_labels[idx])
            booster <- xgb.train(params <- as.list(bt[setdiff(names(bt), "nrounds")]),
                                 data = dtrain, nrounds = bt$nrounds, verbose = 0)
            xgb.save(booster, model_paths[i])    # save as .xgb model
            NULL
          }
  cat("models have saved in：", model_dir, "\n")
}

# Train model of turnover time ####
set.seed(7)
registerDoParallel(96)

model_effect_stock <- train(x = train.data[, c(10:45)],
                            y = train.data$shap_stock,
                            method = "xgbTree",
                            tuneGrid = xgb.tuneGrid,
                            trControl = ctrl)

# Save models as 
saveRDS(model_effect_stock, "./output/soc_effect/model_effect_stock_caret.rds")

# Observed-Predicted 
pred_ob_stock <- data.frame(train.data[, 2:3],
                            Observed = train.data$shap_stock,
                            Predicted = predict(model_effect_stock$finalModel, as.matrix(train.data[, 10:45]), 
                                                na.action = na.pass)) %>%
  mutate(Residual = Observed - Predicted)

#　op_rf_cv <- accuracy_cv(pred_ob_stock)
write.csv(pred_ob_stock, "./output/soc_effect/pred_ob_stock.csv")

# Bootstrap training models 
train_labels <- train.data$shap_stock
bt <- model_effect_stock$bestTune
model_paths <- file.path(model_dir, sprintf("bootstrap_model_stock_%03d.xgb", 1:100))

if (all(file.exists(model_paths))) {
  cat("models have been trained，skip training. \n")
} else {
  cat("traingin 100 bootstrap modles...\n")
  
  registerDoParallel(96)
  
  foreach(i = 1:100, .packages = "xgboost",
          .export = c("train_matrix","train_labels","bt","model_paths")) %dopar% {
            set.seed(7 + i)
            idx <- sample(nrow(train_matrix), nrow(train_matrix), replace = TRUE)
            dtrain <- xgb.DMatrix(data = train_matrix[idx, ], label = train_labels[idx])
            booster <- xgb.train(params <- as.list(bt[setdiff(names(bt), "nrounds")]),
                                 data = dtrain, nrounds = bt$nrounds, verbose = 0)
            xgb.save(booster, model_paths[i])    # save as .xgb model
            NULL
          }
  #parallel::stopCluster(cl)
  cat("models have saved in：", model_dir, "\n")
}


# Train model of turnover time #####
set.seed(7)
registerDoParallel(96)

model_effect_turnover <- train(x = train.data[, c(10:45)],
                               y = train.data$shap_turnover,
                               method = "xgbTree",
                               tuneGrid = xgb.tuneGrid,
                               trControl = ctrl)

# Save models as 
saveRDS(model_effect_turnover, "./output/soc_effect/model_effect_turnover_caret.rds")

# Observed-Predicted 
pred_ob_turnover <- data.frame(train.data[, 2:3],
                               Observed = train.data$shap_turnover,
                               Predicted = predict(model_effect_turnover$finalModel, as.matrix(train.data[, 10:45]), 
                                                   na.action = na.pass)) %>%
  mutate(Residual = Observed - Predicted)

#　op_rf_cv <- accuracy_cv(pred_ob_trunover)
write.csv(pred_ob_turnover, "./output/soc_effect/pred_ob_turnover.csv")

# Bootstrap training models 
train_labels <- train.data$shap_turnover
bt <- model_effect_turnover$bestTune
model_paths <- file.path(model_dir, sprintf("bootstrap_model_turnover_%03d.xgb", 1:100))

if (all(file.exists(model_paths))) {
  cat("models have been trained，skip training. \n")
} else {
  cat("traingin 100 bootstrap modles...\n")
  
  registerDoParallel(96)
  
  foreach(i = 1:100, .packages = "xgboost",
          .export = c("train_matrix","train_labels","bt","model_paths")) %dopar% {
            set.seed(7 + i)
            idx <- sample(nrow(train_matrix), nrow(train_matrix), replace = TRUE)
            dtrain <- xgb.DMatrix(data = train_matrix[idx, ], label = train_labels[idx])
            booster <- xgb.train(params <- as.list(bt[setdiff(names(bt), "nrounds")]),
                                 data = dtrain, nrounds = bt$nrounds, verbose = 0)
            xgb.save(booster, model_paths[i])    # save as .xgb
            NULL
          }
  
  #parallel::stopCluster(cl)
  cat("models have saved in：", model_dir, "\n")
}

