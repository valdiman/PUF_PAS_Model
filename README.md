# PUF_PAS_Model

## Version

**Version 2.0 — September 2026**

## License

PUF_PAS_Model is licensed under the 2-Clause BSD License. See the [LICENSE](LICENSE) file for details.

---

## General Information

**Deposit Title:** PCB PUF-PAS Effective Volume Model

### Contributor Information

Andres Martinez, PhD  
University of Iowa - Department of Civil & Environmental Engineering  
Iowa Superfund Research Program (ISRP)  
andres-martinez@uiowa.edu  
ORCID: 0000-0002-0572-1494

Originally created: March 10, 2025  
Current version: September 2026

This work was supported by the National Institute of Environmental Health Sciences (NIEHS) grant P42ES013661.

This R project calculates congener-specific sampling rates and effective sampling volumes for polyurethane foam passive air samplers (PUF-PAS) for all 209 PCB congeners.

The project also includes scripts for obtaining and processing hourly meteorological data from NOAA GHCNh and MERRA-2.

---

## Prerequisites and Dependencies

The following software is required:

- R
- RStudio Desktop
- A web browser (e.g., Google Chrome, Microsoft Edge, Mozilla Firefox)

RStudio Desktop can be downloaded from:

https://posit.co/download/rstudio-desktop/

Required R packages are identified and installed by the individual meteorological-processing scripts.

---

## R Project Structure

The repository is organized as an R project. Open:

`PUF_PAS_Model.Rproj`

in RStudio to ensure that the project root is used as the working directory.

The main project structure is:

```text
PUF_PAS_Model/
│
├── Data/
│   └── PCB physicochemical-property input files
│
├── Documentation/
│   └── Step-by-Step User Guide
│
├── Output/
│   └── Meteorological data and model results
│
├── R/
│   ├── Meteorology/
│   └── PufPasEffectiveVolume/
│
├── LICENSE
├── README.md
├── Subfolders.R
└── PUF_PAS_Model.Rproj
```

The `Subfolders.R` script can be used to create the required output subfolders if they do not already exist.

---

## Meteorological Data

Meteorological data can be obtained from NOAA GHCNh or MERRA-2.

### NOAA GHCNh

The primary NOAA workflow uses the Global Historical Climatology Network hourly (GHCNh) dataset.

The GHCNh meteorological-processing script is located in:

`R/Meteorology/`

The script downloads and processes hourly meteorological observations for a selected NOAA GHCNh station.

The user specifies:

- GHCNh station ID
- Start year
- End year
- Processing mode

Two processing modes are available:

### `full_year`

Use this option for completed calendar years.

### `end_date`

Use this option when the final year is incomplete or when meteorological processing should stop at a specific date.

When using `end_date`, the user specifies:

- End year
- End month
- End day

The script fills missing meteorological observations within the selected data period but does not extend meteorological values beyond the last actual reported GHCNh observation.

NOAA GHCNh stations and data availability can be searched at:

https://www.ncei.noaa.gov/access/search/datasets/global-historical-climatology-network-hourly/

### MERRA-2

The MERRA-2 meteorological-processing script is located in:

`R/Meteorology/`

The user specifies the sampling-site longitude and latitude and the required start and end dates.

MERRA-2 can be used when a suitable nearby NOAA station is unavailable or when the required station record does not cover the sampling period.

---

## Processed Meteorological Data

The processed meteorological files contain the following variables:

- `date` — date and time in UTC
- `TA` — atmospheric temperature in Kelvin
- `Pr` — atmospheric pressure in Pa
- `WS` — wind speed in m/s
- `WD` — wind direction in degrees
- `QV` — water-vapor quantity used by the PUF-PAS model

Processed NOAA GHCNh data are stored under:

`Output/Data/GHCNh/`

Processed MERRA-2 data are stored under:

`Output/Data/MERRA/`

---

## PUF-PAS Effective Volume Model

The effective-volume scripts are located under:

`R/PufPasEffectiveVolume/`

The effective-volume model uses the processed meteorological data together with the PUF-PAS deployment and collection times and PCB physicochemical-property data.

For each model run, the user specifies:

1. Deployment start date and time
2. Collection end date and time
3. Path to the processed meteorological data
4. PCB physicochemical-property input files
5. Output path and filename

Deployment and collection times should be entered in UTC using:

`YYYY-MM-DD HH:MM:SS`

For example:

```r
start_date = "2018-12-01 01:00:00"
end_date   = "2019-01-10 01:00:00"
```

---

## Model Output

The PUF-PAS model calculates:

- Congener-specific sampling rate (`SR`, m³/day)
- Congener-specific effective sampling volume (`Veff`, m³)
- Deployment and collection times
- Deployment length
- Percentage of wind-speed observations greater than 5 m/s

Calculations are performed for all 209 PCB congeners.

Model results are stored under:

`Output/Data/Results/`

with subfolders corresponding to the meteorological data source.

---

## Step-by-Step User Guide

Detailed instructions for downloading, configuring, and running the PUF-PAS model in RStudio are provided in:

[PUF-PAS Model Step-by-Step Guide — Version 2.0](Documentation/PUF-PAS_Model_Step-by-Step_Guide_GHCNh_V02.pdf)

The guide includes instructions for:

- Setting up the R project
- Selecting NOAA GHCNh stations
- Processing complete historical years
- Processing an incomplete/current year using a selected end date
- Processing MERRA-2 meteorological data
- Running the PUF-PAS effective-volume model
- Locating and interpreting model output

---

## Reproducibility

Meteorological and model-output CSV files are generated by the R scripts and are not intended to be version-controlled in the GitHub repository.

The repository contains the R scripts, PCB physicochemical-property files, documentation, and other project files required to reproduce the model calculations.

---

## Citation

When using the PUF-PAS model, please cite the corresponding archived release available through Zenodo.

See the Zenodo record associated with this repository for the DOI and version-specific citation.
