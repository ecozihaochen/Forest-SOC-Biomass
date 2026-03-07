# Spatial prediction of the SOC attribute effect, This script use soc flux as an example,
# Run on the Tier-2 wICE cluster, which is located in the high-performance computing facilities of Flanders.

# Load package ####
library("foreach")
library("doParallel")
library("caret")
library("terra")
library("xgboost")
library("dplyr")


# load data ####
train.data <- read.csv("./input/soc_effects.csv")
out_dir    <- "./output/geotiff/bootstrap_effect"
model_dir  <- "./output/soc_effect/bootstrap_models"
var_dir <- "./Geotiff"
dir.create(out_dir,   recursive = TRUE, showWarnings = FALSE)
dir.create(model_dir,   recursive = TRUE, showWarnings = FALSE)

vars <- colnames(train.data)[10:45]

# set paths and blocks
model_paths <- file.path(model_dir, sprintf("bootstrap_model_flux_%03d.xgb", 1:100))
file_paths  <- file.path(var_dir, paste0(vars, ".tif"))

R0 <- rast(file_paths[1])
raster_extent <- terra::ext(R0)
crs_str <- terra::crs(R0[[1]])
rm(R0)

lat_step <- 14; lon_step <- 15
lat_ranges <- seq(raster_extent[3], raster_extent[4], by = lat_step)
lon_ranges <- seq(raster_extent[1], raster_extent[2], by = lon_step)

# Do parallel ####
registerDoParallel(50)

foreach(n = 1:100, .packages = c("terra", "xgboost", "dplyr"),
        .errorhandling = "pass", .verbose = TRUE) %dopar%  {
  out_name <- file.path(out_dir, sprintf("predict_flux_%03d.tif", n))
  temp_dir <- file.path("./output/soc_effect/temp_flux", sprintf("temp_model_flux_%03d", n))
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  
  model <- xgboost::xgb.load(normalizePath(model_paths[n], winslash = "/"))
  
  rasters <- rast(file_paths)
  
  for (i in 1:(length(lat_ranges) - 1)) {
    for (j in 1:(length(lon_ranges) - 1)) {
      
      # Generate unique tile filename
      lat_min_label <- ifelse(lat_ranges[i] >= 0, "N", "S")
      lon_max_label <- ifelse(lon_ranges[j + 1] >= 0, "E", "W")
      partition_name <- paste0(abs(round(lat_ranges[i + 1], 2)), lat_min_label, "_", 
                               abs(round(lon_ranges[j + 1], 2)), lon_max_label)
      tile_name <- sprintf("tile_%s.tif", partition_name)
      tile_path <- file.path(temp_dir, tile_name)
      
      sub_extent <- ext(lon_ranges[j], lon_ranges[j + 1], lat_ranges[i], lat_ranges[i + 1])
      sub_raster <- crop(rasters, sub_extent)
      
      if (inherits(sub_raster, "try-error")) next
      names(sub_raster) <- vars

      m <- terra::minmax(sub_raster[["bio1"]])
      if (all(is.na(m))) next   # skip if all NA
      
      # Predict using terra's efficient method
      predict(sub_raster, model,
              fun = function(model, data) {predict(model, as.matrix(data))},
              filename = tile_path,
              overwrite = TRUE,
              wopt = list(gdal = c("COMPRESS=DEFLATE", "TILED=YES","BIGTIFF=YES")))
      
      rm(sub_raster, m); gc()
    }
  }
  
  rm(model); gc()
  
  tiles <- list.files(temp_dir, pattern = "\\.tif$", full.names = TRUE)
  if (length(tiles) > 0) {
    sc <- terra::sprc(tiles)
    terra::mosaic(sc, fun = "first", filename = out_name, overwrite=TRUE,
                  wopt = list(gdal = c("COMPRESS=DEFLATE","TILED=YES","BIGTIFF=YES")))
    rm(sc)
  }
  # Cleanup temporary files
  unlink(temp_dir, recursive = TRUE)
  
  NULL
}



