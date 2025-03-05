# PUF_PAS_Model
## License

PUF_PAS_Model is licensed under the 2-Clause BSD License - see the [LICENSE](LICENSE) file for details.

----------------------
General Information
----------------------

Deposit Title: PCB PUF-PAS effective volume model

Contributor information:

Andres Martinez, PhD
University of Iowa - Department of Civil & Environmental Engineering
Iowa Superfund Research Program (ISRP)
andres-martinez@uiowa.edu
ORCID: 0000-0002-0572-1494

This README file was generated on March 10, 2025 by Andres Martinez.

This work was supported by the National Institutes of Environmental Health Sciences (NIEHS) grant #P42ES013661.

This README file describes the project in R to calculate individual PCB sampling rates and effective volumes for a PUF-PAS sampler, in addition to obtain the meteorological data from two sources: MERRA and NOAA.

--------
PREREQUISITES & DEPENDENCIES
--------

This section of the ReadMe file lists the necessary software required to run codes in "R".

Software:
- Any web browser (e.g., Google Chrome, Microsoft Edge, Mozilla Firefox, etc.)
- R-studio for easily viewing, editing, and executing "R" code as a regular "R script" file:
https://www.rstudio.com/products/rstudio/download/

--------
SOFTWARE INSTALLATION
--------

This section of the ReadMe file provides short instructions on how to download and install "R Studio".  "R Studio" is an open source (no product license required) integrated development environment (IDE) for "R" and completely free to use.  To install "R Studio" follow the instructions below:

1. Visit the following web address: https://www.rstudio.com/products/rstudio/download/
2. Click the "download" button beneath RStudio Desktop
3. Click the button beneath "Download RStudio Desktop".  This will download the correct installation file based on the operating system detected.
4. Run the installation file and follow on-screen instructions. 

--------
R FILES AND STRUCTURE
--------
It is recommended to create a project in R (e.g., PUF-PAS.Rproj). Download the project file (.Rproj) and the R subfolder where the scripts are located, and the Subfolders.R file. Run first the Subfolder.R file, which will generate all the subfolders for this project.
The structure of this project includes an R subfolder where all the R scripts are located, as previoulsy indicated. There is a Data subfolder where the physico-chemical properties of the individual PCB congeners are stored, and then an Output subfolder, where the results from the meteorological and PUF-PAS efective volumnes are going to be storaged.
The R subfolder is also subdivided into Meteorology and PufPasEffectiveVolume subfolders.

The meteorological data are generated in these 2 scripts:

process_isd_met_dataV01.R

process_MERRA_dataV01.R

These scritps generate data are used in the two scripts to generate the effective volumes:

PUF_PAS_Effective_Volume_ModelMERRA.R

PUF_PAS_Effective_Volume_ModelVFinal.R

Small adjustements need to be performed in these 2 scripts: (1) select folder to read the meteorological data, (2) include the deployemnts dates for each PUF-PAS,  (3) create a folder to storage the results. After running any of the meteorological scripts, a new forders will be created in the Output/Data folder, i.e., isd_light and MERRA. Similarly, after running any of the PUF_PAS scripts, a new folder will be created in the Output/Data/Results, isd_light and MERRA too.

The meteorological output files will contain date, TA (atmospheric temperature in C), Pr (atmospheric pressure in Pa), WS (wind speed in m/s), WD (wind direccion in degrees) and QV (kg/kg). 

The PUF_PAS_Effective_Volume_Mode scripts will contain the PUf_ID (in this case it will be just one), the deployment times, the length in days, % of excedense on the WS (> 5 m/s), type (Veff and SR) and Veff and SR for all 209 PCB congeners.




