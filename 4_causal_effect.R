# causal effect of soc flux and stock on forest biomass, this script use soc flux as an example

# Load package
library("grf")
library("dplyr")
library("data.table")
library("terra")

# pre analysis ####
df <- fread("./input/environmental_variables.csv")

X_raw <- subset(df, select = -c(forest_biomass, flux))
X <- model.matrix(~ . - 1, data = X_raw)
Y <- df$forest_biomass
W <- df$flux

x_mm_cols  <- colnames(X)
x_vars_raw <- colnames(X_raw)

saveRDS(list(x_mm_cols = x_mm_cols, x_vars_raw = x_vars_raw), "./output/causal_effect/cf_meta_flux.rds")

cf_tune <- causal_forest(
  X, Y, W,
  num.trees       = 4000,
  tune.parameters = "all",
  tune.num.trees  = 1000,
  num.threads     = 0)

saveRDS(cf_tune, "./output/causal_effect/cf_tune_flux.rds")

p <- cf_tune$tunable.params

best <- list(
  sample.fraction   = p[["sample.fraction"]],
  mtry              = p[["mtry"]],
  min.node.size     = p[["min.node.size"]],
  alpha             = p[["alpha"]],
  imbalance.penalty = p[["imbalance.penalty"]])

print(best)
saveRDS(best, "./output/causal_effect/cf_best_params_flux.rds")

# causal forest ####
cf <- causal_forest(
  X, Y, W,
  num.trees         = 5000,       
  tune.parameters   = "none",
  sample.fraction   = best$sample.fraction,
  mtry              = best$mtry,
  min.node.size     = best$min.node.size,
  alpha             = best$alpha,
  imbalance.penalty = best$imbalance.penalty)

saveRDS(cf, "./output/causal_effect/causal_forest_flux.rds")


# Extrapolation causal effect of soc flux on forest biomass ####
X_raw <- subset(df, select = -c(forest_biomass, flux))
X_raw <- model.matrix(~ . - 1, data = X_raw)

cf <- readRDS("./output/causal_effect/causal_forest_flux.rds")

load_rasters <- function(path = "./Geotiff") {
  files <- c(paste0("bio", 1:19), "Roughness", "Slope", "Depth_rock", "Bulk", "CFVO", "Clay", "Sand",
             "Erodibility", "WV1", "WV2", "WV3", "SM_Driest", "SM_Mean", "SM_Wettest",
             "HANPP", "NPP", "EVI", "EVI_Contrast", "EVI_Dissimilarity", "EVI_Entropy", "EVI_Homogeneity",
             "Forest_age", "plant_diversity", "tree_density", "human_modification","Tree_cover", "forest_biomass")
  
  file_paths <- file.path(path, paste0(files, ".tif"))
  miss <- file_paths[!file.exists(file_paths)]
  if (length(miss) > 0) stop("Missing raster files:\n", paste(miss, collapse = "\n"))
  s <- rast(file_paths)
  names(s) <- files
  s
}

stacked_rasters <- load_rasters()
raster_extent <- ext(stacked_rasters)
lat_step <- 10
lon_step <- 20

lat_ranges <- seq(raster_extent[3], raster_extent[4], by = lat_step)
lon_ranges <- seq(raster_extent[1], raster_extent[2], by = lon_step)

pred_list <- list()
var_list  <- list()

for (i in 1:(length(lat_ranges) - 1)) {
  for (j in 1:(length(lon_ranges) - 1)) {
    
    sub_extent <- ext(lon_ranges[j], lon_ranges[j + 1], lat_ranges[i], lat_ranges[i + 1])
    sub_raster <- crop(stacked_rasters, sub_extent)
    
    df_pred <- as.data.frame(sub_raster, xy = TRUE, na.rm = FALSE) %>% filter(!is.na(Tree_cover))
    
    lon_max_label <- ifelse(lon_ranges[j + 1] >= 0, "E", "W")
    lat_min_label <- ifelse(lon_ranges[j] >= 0, "N", "S")
    partition_name <- paste0(abs(round(lat_ranges[i + 1], 2)), lat_min_label, "_", 
                             abs(round(lon_ranges[j + 1], 2)), lon_max_label)
    
    if (nrow(df_pred) > 0 && any(!is.na(df_pred$Tree_cover))) {
      
      df0 <- as.matrix(df_pred[, colnames(X_raw)])
      
      pred <- predict(cf, df0, estimate.variance = TRUE)
      
      # prediction
      df_out <- df_pred[, c("x", "y")]
      df_out$prediction <- pred$predictions  
      predict_raster <- terra::rast(df_out)
      crs(predict_raster) <- crs(stacked_rasters[[1]])
      pred_list[[length(pred_list) + 1]] <- predict_raster
      
      # variance
      df_var <- df_pred[, c("x", "y")]
      df_var$variance <- pred$variance.estimates
      variance_raster <- terra::rast(df_var)
      crs(variance_raster) <- crs(stacked_rasters[[1]])
      var_list[[length(var_list) + 1]] <- variance_raster
      
      print(paste(partition_name, "saved in predict list"))
      
    }
  }
  gc()
}

rm(df, pred, df_out, sub_raster, predict_raster)

if (length(pred_list) > 0) {
  merged_raster <- do.call(merge, pred_list)
  merged_raster <- resample(merged_raster, stacked_rasters[[1]], method = "near")
  out_name <- c("./output/causal_effect/CATE_flux.tif")
  writeRaster(merged_raster, filename = out_name, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
}


if (length(var_list) > 0) {
  merged_varience <- do.call(merge, var_list)
  merged_varience <- resample(merged_varience, stacked_rasters[[1]], method = "near")
  out_name <- paste0("./output/causal_effect/CATE_flux_variance.tif")
  writeRaster(merged_varience, filename = out_name, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
}



