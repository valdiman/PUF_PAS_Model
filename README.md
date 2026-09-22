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
University of Iowa  
Department of Civil & Environmental Engineering  
Iowa Superfund Research Program (ISRP)  
andres-martinez@uiowa.edu  
ORCID: 0000-0002-0572-1494

Originally created: March 10, 2025  
Current version: September 2026

This work was supported by the National Institute of Environmental Health Sciences (NIEHS) grant P42ES013661.

This R project calculates congener-specific sampling rates and effective sampling volumes for polyurethane foam passive air samplers (PUF-PAS) for all 209 PCB congeners.

The project also includes scripts for obtaining and processing hourly meteorological data from NOAA and MERRA-2.

---

## Prerequisites and Dependencies

The following software is required:

- R
- RStudio Desktop
- A web browser (e.g., Google Chrome, Microsoft Edge, Mozilla Firefox)

RStudio Desktop can be downloaded from:

https://posit.co/download/rstudio-desktop/

Required R packages are identified and installed by the individual meteorological processing scripts.

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
