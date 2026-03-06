# Forest-SOC-Biomass

This repository contains the code used for the analysis in the paper: Chen et al. 2026. Soil organic carbon flux is a more critical driver of global forest biomass than carbon stock.

We developed an integrative analytical framework to disentangle the influence of SOC stock from its dynamic attributes (flux and turnover time) on forest biomass globally. Using a compiled global dataset of 41,899 forest soil profiles, we derived three SOC attributes (stock, flux, and turnover time) standardized to a 0–1 m depth interval.

Based on Extreme gradient boosting (XGBoost) algorithm and Shapley Additive Explanations (SHAP) to decompose predictions into the contributions of each SOC attribute and environmental covariates, thereby quantifying their respective controls on forest biomass across global environmental gradients. Based on this, we delineated SOC “hotspots” where specific attributes exert disproportionately strong control on biomass, providing the first spatially explicit global view of the functional geography of soil–vegetation coupling.
<br><br>
## Workflow
<p align="center"><img src="figure/workflow.png" width="550"></p>


## Description
- figure: Output folder where all generated figures are saved.
- geotiff: Folder containing the GeoTIFF files of the 33 environmental covariates used in the modeling.
- input: CSV file containing 41,899 observations after preprocessing and PCA analysis, including forest biomass, SOC attributes (flux, stock, and turnover time), and 9 principal components.
- output: GeoTIFF files of SHAP values for three SOC attributes (flux, stock, and turnover time) and CATE values for flux and stock at 1 km resolution. Due to file size limitations, the files have been uploaded to Zenodo (link).

## License
The code and data shared in this study by [Zihao Chen](https://ecozihaochen.github.io/) are licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/?ref=chooser-v1).
