# PUF_PAS_Model

## Version

**Version 2.1 — October 2026**

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
Current version: 2.1 — October 2026

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

The primary NOAA meteorological workflow uses the Global Historical
Climatology Network hourly (GHCNh) dataset.

The GHCNh meteorological-processing script is located at:

`R/Meteorology/process_GHCNh_dataV02.R`

The script downloads and processes meteorological observations for
a selected NOAA GHCNh station and specified years.

#### Hourly Observation Processing

GHCNh observations are processed using an hourly observation-selection
procedure designed to maintain consistency with the historical NOAA
ISD-Lite dataset.

Rather than averaging all observations within each clock hour, the
script selects representative observations near the hourly boundary
and assigns them to the corresponding hourly timestamp.

Comparisons with ISD-Lite observations demonstrated excellent agreement
for temperature, atmospheric pressure, wind speed, wind direction,
and calculated water-vapor mixing ratio over the evaluated period.

The procedure approximates the ISD-Lite hourly observation-selection
method but does not reproduce NOAA's complete quality-ranking algorithm.

#### Station and Year Selection

The user specifies:

- GHCNh station ID
- Start year
- End year

For example, to process meteorological observations from Chicago
O'Hare International Airport for 2025:

```r
# Chicago O'Hare International Airport
metdataID <- "USW00094846"
start_year <- 2025
end_year <- 2025
```

The script processes the specified calendar years.

For incomplete years, the processed meteorological dataset stops
at the last available hourly observation rather than extending
through December 31.

#### Missing Meteorological Observations

The script identifies missing meteorological observations and reports
the number and percentage of missing hours for each variable.

It also identifies the longest consecutive missing-data period for
each meteorological variable and generates a warning when the
period exceeds 72 consecutive hours.

Missing observations within the available data period are replaced
using forward-filling and backward-filling procedures.

The water-vapor mixing ratio is recalculated using dew-point
temperature and atmospheric pressure after missing values
have been filled.

The processed meteorological dataset is saved as a single CSV file
for use in the PUF-PAS effective-volume model.

#### Processed GHCNh Output

Processed meteorological data are stored under:

`Output/Data/GHCNh/<Station_ID>/`

For example:

`Output/Data/GHCNh/USW00094846/USW00094846-2025-2025-GHCNh-filled.csv`

The output contains hourly meteorological observations with
temperature in Kelvin, atmospheric pressure in Pascals,
wind speed in m/s, wind direction in degrees, and water-vapor
mixing ratio in kg/kg.

NOAA GHCNh stations and data availability can be searched at:

https://www.ncei.noaa.gov/access/search/datasets/global-historical-climatology-network-hourly/

---

### MERRA-2

The MERRA-2 meteorological-processing script is located in:

`R/Meteorology/`

The user specifies the sampling-site longitude and latitude and the required start and end dates.

MERRA-2 can be used when a suitable nearby NOAA station is unavailable or when the required station record does not cover the sampling period.

---

## Processed Meteorological Data

The PUF-PAS effective-volume model uses hourly meteorological data
obtained from NOAA GHCNh, NOAA ISD-Lite, or MERRA-2.

Processed meteorological files contain the following variables:

| Variable | Description | Units |
|---|---|---|
| `date` | Date and time | UTC |
| `TA` | Atmospheric temperature | K |
| `Pr` | Atmospheric pressure | Pa |
| `WS` | Wind speed | m/s |
| `WD` | Wind direction | degrees |
| `QV` | Water-vapor mixing ratio | kg/kg |

The GHCNh processing workflow calculates QV from dew-point
temperature and atmospheric pressure after missing meteorological
observations have been filled.

The processed meteorological files are formatted for use in the
PUF-PAS effective-volume model.

Processed NOAA GHCNh data are stored under:

`Output/Data/GHCNh/`

Processed NOAA ISD-Lite data are stored under:

`Output/Data/isd_light/`

Processed MERRA-2 data are stored under:

`Output/Data/MERRA/`

---

## PUF-PAS Effective Volume Model

The PUF-PAS effective-volume calculation scripts are located under:

`R/PufPasEffectiveVolume/`

The model calculates congener-specific sampling rates and effective
sampling volumes using hourly meteorological observations, PUF sampler
characteristics, and PCB physicochemical-property data.

Calculations are performed for all 209 PCB congeners.

### Scientific Model Formulation

The R implementation follows the meteorology-dependent PUF-PAS model
developed by Petrich et al. (2013) and Herkert et al. (2016).

The model retains the original published equations for:

- Internal air velocity within the PUF-PAS chamber
- PCB molecular diffusivity
- Kinematic viscosity
- Air-side mass-transfer coefficient
- Temperature- and wind-dependent empirical calibration parameter (gamma)
- PUF-air partitioning
- Effective sampling volume

Version 2.1 improves meteorological data processing and input validation
without modifying the original scientific model equations.

The original viscosity and gamma formulations are retained to preserve
consistency with the published empirical calibration.

### Model Configuration

For each model run, the user specifies:

1. Deployment start date and time
2. Collection end date and time
3. Path to the processed meteorological data
4. PCB physicochemical-property input files
5. Output path and filename

Deployment and collection times must be entered in UTC using:

`YYYY-MM-DD HH:MM:SS`

For example:

```r
start_date = "2025-03-01 01:00:00"
end_date   = "2025-04-10 01:00:00"
```

### Meteorological Input Validation

The model verifies that the requested deployment and collection
timestamps are present in the meteorological dataset.

Meteorological variables are selected by column name rather than
column position.

The model checks for missing or invalid temperature, pressure,
wind-speed, and water-vapor mixing-ratio values during the selected
deployment period.

The meteorological input files must contain continuous hourly
observations covering the complete deployment period.

The model uses the following meteorological variables:

- `TA` — atmospheric temperature (K)
- `Pr` — atmospheric pressure (Pa)
- `WS` — wind speed (m/s)
- `QV` — water-vapor mixing ratio (kg/kg)

Wind direction (`WD`) is included in the processed meteorological
datasets but is not directly used in the current effective-volume
calculations.

### Meteorological Data Sources

The model can use processed meteorological data from:

- NOAA GHCNh
- NOAA ISD-Lite
- MERRA-2

The meteorological input file is selected using the `met_data_path`
argument.

For example:

```r
met_data_path =
  "Output/Data/GHCNh/USW00094846/USW00094846-2025-2025-GHCNh-filled.csv"
```

All meteorological input files must use the required column names,
units, and UTC timestamps.

### Deployment Length

The model calculates effective sampling volumes at hourly time steps.

The current implementation includes both deployment and collection
timestamps when selecting meteorological observations.

Consequently, the number of hourly records is one greater than
the elapsed deployment duration expressed in whole hours.

This convention is retained for consistency with the original
model implementation.

---

## Model Output

The PUF-PAS model calculates congener-specific sampling rates and
effective sampling volumes for all 209 PCB congeners.

The output CSV contains the following information:

| Column | Description | Units |
|---|---|---|
| `PUF_ID` | PUF-PAS sampler identifier | — |
| `Deployment` | Deployment start date and time | UTC |
| `Collection` | Collection end date and time | UTC |
| `Length` | Number of hourly meteorological records | hours (records) |
| `WS_Exceedence` | Percentage of wind-speed observations greater than 5 m/s | % |
| `Type` | Calculated output variable (`Veff` or `SR`) | — |
| PCB congeners (1–209) | Congener-specific calculated values | m³ or m³/day |

For each deployment, the model generates two rows:

- `Veff` — Congener-specific effective sampling volume (m³).
- `SR` — Congener-specific average sampling rate (m³/day).

Deployment and collection timestamps are saved using:

`YYYY-MM-DD HH:MM:SS`

The `Length` column represents the number of hourly records used in
the calculations, including both deployment and collection timestamps.

For example, a deployment lasting 40 days contains 961 hourly records
(960 elapsed hours plus the collection timestamp).

Model results are stored under:

`Output/Data/Results/`

with subfolders corresponding to the meteorological data source.

For example, GHCNh results are stored under:

`Output/Data/Results/GHCNh/`

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

## Version History

### Version 2.1 — October 2026

- Updated NOAA GHCNh meteorological processing (V02).
- Implemented representative hourly observation selection to improve consistency with historical ISD-Lite data.
- Corrected the water-vapor mixing-ratio (QV) calculation.
- Added missing-data percentages and warnings for gaps exceeding 72 consecutive hours.
- Improved handling of incomplete meteorological years.
- Implemented exact UTC deployment and collection timestamp matching.
- Improved meteorological input validation.
- Standardized deployment and collection date formatting in model outputs.
- Retained the original published PUF-PAS viscosity, mass-transfer, and empirical gamma calibration equations.

### Version 2.0 — September 2026

- Updated the R project structure and documentation.
- Introduced NOAA GHCNh and MERRA-2 meteorological-processing workflows.
- Updated the PUF-PAS effective-volume model implementation.

## Citation

When using the PUF-PAS model, please cite the corresponding archived release available through Zenodo.

See the Zenodo record associated with this repository for the DOI and version-specific citation.
