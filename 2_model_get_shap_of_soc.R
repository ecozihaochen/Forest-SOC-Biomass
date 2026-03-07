# Load package
library("iterators")
library("foreach")
library("dplyr")
library("doParallel")
library("xgboost")
library("lattice")
library("caret")
library("data.table")
library("terra")

# Load training data 
train.data <- fread("./input/environmental_variables_pca.csv")

# 1200 parameters ####
xgb.tuneGrid <- expand.grid(eta = c(0.001, 0.002, 0.005, 0.01, 0.02, 0.05),     
                            nrounds = seq(50, 500, by = 50),                               
                            max_depth = c(8:12),               
                            min_child_weight = c(2:5),   
                            gamma = 0,
                            colsample_bytree = c(0.9),
                            subsample=  c(0.9))

ctrl <- trainControl(method = "cv", number = 10, allowParallel = TRUE, savePredictions = "final")

# Train XGBoost model of biomass ####
set.seed(7)
registerDoParallel(96)

model_biomass <- train(x = train.data[, c(7:18)],
                       y = train.data$forest_biomass,
                       method = "xgbTree",
                       tuneGrid = xgb.tuneGrid,
                       trControl = ctrl)

saveRDS(model_biomass, "./output/biomass_pca_xgb/model_biomass_caret.rds")

# 100 bootstraps and calculate SHAP values of each soc attribute ####
x_mat <- as.matrix(train.data[, 7:18, with = FALSE])
y_num <- as.numeric(train.data$forest_biomass)
features <- c("stock", "flux", "turnover")

best <- model_biomass$bestTune

registerDoParallel(96)

shap_res <- foreach(i = 1:100, .packages = c("caret", "xgboost", "data.table")) %dopar% {
  
  fit_i <- train(x = x_mat,
                 y = y_num,
                 method = "xgbTree",
                 tuneGrid = best,
                 trControl = ctrl,
                 verbose = FALSE)
  
  # final model (xgb.Booster)
  xgb_i <- fit_i$finalModel
  dX_i <- xgb.DMatrix(x_mat)
  
  # SHAP: predcontrib=TRUE
  shap_i <- predict(xgb_i, dX_i, predcontrib = TRUE)
  shap_i <- shap_i[, colnames(shap_i) != "BIAS", drop = FALSE]
  # SHAP of SOC attributes
  shap_sub <- shap_i[, features, drop = FALSE]
  colnames(shap_sub) <- paste0(features, "_", i)
  
  as.data.table(shap_sub)
}

shap_soc <- as.data.table(do.call(cbind, shap_res))

for (f in features) {
  cols_f <- grep(paste0(f, "_\\d+$"), names(shap_soc), value = TRUE)
  shap_soc[, paste0(f, "_mean") := rowMeans(.SD), .SDcols = cols_f]
}

write.csv(shap_soc, "./output/biomass_pca_xgb/bootstrap_shap_of_soc_attributes.csv")


model_biomass <- readRDS("./output/biomass_pca_xgb/model_biomass_caret.rds")

pred_ob_biomass <- data.frame(train.data[, 2:3],
                           Observed = train.data$forest_biomass,
                           Predicted = predict(model_biomass$finalModel, as.matrix(train.data[, 7:18]), 
                                               na.action = na.pass)) %>%
  mutate(Residual = Observed - Predicted)

write.csv(pred_ob_biomass, "./output/soc_effect/pred_ob_biomass.csv", row.names = F)


shap_soc <- read.csv("./output/biomass_pca_xgb/bootstrap_shap_of_soc_attributes.csv")

