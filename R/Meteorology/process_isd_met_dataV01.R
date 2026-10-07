# Install package
install.packages('dplyr')
install.packages('tidyr')
install.packages('zoo')
install.packages('R.utils')

# Load necessary libraries
{
  library(dplyr)
  library(tidyr)
  library(zoo)
  library(R.utils)
}

# Select station, years ---------------------------------------------------
# Define variables
# metDataID or Station ID can be found @ https://www.ncei.noaa.gov/maps/global-summaries/
# Open the Map:
# Make sure the map is loaded and centered on the region of interest.
# Enable the Station Layer: On the top left corner, there's a "Layer" button (wrench).
# Click on this to open the layer settings. Ensure that "GHCN
# (Global Historical Climatology Network)
# Stations" or "Global Summary of the Day (GSOD) Stations" is enabled.
# These are the layers that show the weather stations on the map. Zoom In to
# the Area of Interest:
# Use the zoom tool or scroll to zoom into the area where you want to find
# weather stations. You will see station markers appearing on the map as you
# zoom in. Click on the Identity ("I") on the Station Marker:
# This will bring the info on the left panel, i.e., name of the station, period of record and Station ID
# station information. 
# Station ID: XXXXXXXXXXX need to add "-" after the sixth digit.
metdataID <- "725300-94846"  # Example ID 725300-94846 O'Hare Chicago
start_year <- 2015          # Start year
num_years <- 1               # Number of years to include (start_year + 1)

# Functions ---------------------------------------------------------------
# Generate a sequence of years
years <- start_year:(start_year + num_years - 1)

# Create a directory for output storage
output_dir <- file.path("Output/Data/isd_light", metdataID) # the name of the file will be metdataID (Station)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Initialize an empty list to store data frames
data_list <- list()

for (i in seq_along(years)) {
  iYear <- years[i]
  
  # Define file paths
  base_url <- "https://www1.ncdc.noaa.gov/pub/data/noaa/isd-lite/"
  file_name <- paste0(metdataID, "-", iYear, ".gz")
  file_url <- paste0(base_url, iYear, "/", file_name)
  file_path <- file.path(output_dir, gsub(".gz$", "", file_name))
  
  # Download and unzip the file
  download.file(file_url, destfile = file.path(output_dir, file_name),
                mode = "wb")
  R.utils::gunzip(file.path(output_dir, file_name), remove = TRUE)
  
  # Read the data into R
  InputData <- read.table(file_path, header = FALSE)
  
  # Extract and convert columns
  Year <- InputData[, 1]
  month <- InputData[, 2]
  day <- InputData[, 3]
  hour <- InputData[, 4]
  TA <- InputData[, 5] / 10  # Temperature (Celsius)
  TD <- InputData[, 6] / 10  # Dew point (Celsius)
  Pr <- InputData[, 7] * 10  # Pressure (Pascals)
  WD <- InputData[, 8]       # Wind direction (degrees)
  WS <- InputData[, 9] / 10  # Wind speed (m/s)
  
  # Create the "date" column
  date <- as.POSIXct(paste(Year, sprintf("%02d", month), sprintf("%02d", day),
                           sprintf("%02d", hour), sep = "-"),
                     format = "%Y-%m-%d-%H", tz = "UTC")
  
  # Create a new data frame with the formatted data
  Met_Data <- data.frame(date = date, TA = TA, TD = TD, Pr = Pr,
                         WS = WS, WD = WD)
  
  # Append to the list
  data_list[[i]] <- Met_Data
}

# Combine data frames from all years
combined_data <- bind_rows(data_list)

# Define the range of dates
start_date <- min(combined_data$date, na.rm = TRUE)
end_date <- max(combined_data$date, na.rm = TRUE)

# Generate a complete sequence of hours and merge with the original data
all_hours <- seq(from = start_date, to = end_date, by = "hour")

merged_data <- data.frame(date = all_hours) %>%
  left_join(combined_data, by = "date")

# Define missing value indicators
missing_values <- list(
  TA = -999.9,
  TD = -999.9,
  WS = -999.9,
  Pr = -99990,
  WD = -9999
)

# Replace missing values with NA before calculating QV
merged_data <- merged_data %>%
  mutate(
    TA = replace(TA, TA == missing_values$TA, NA_real_),
    TD = replace(TD, TD == missing_values$TD, NA_real_),
    WS = replace(WS, WS == missing_values$WS, NA_real_),
    Pr = replace(Pr, Pr == missing_values$Pr, NA_real_),
    WD = replace(WD, WD == missing_values$WD, NA_real_)
  )

# Calculate QV column
calculate_water_vapor <- function(TD, TA, Pr) {
  
  # Return NA if any required variable is missing
  if (is.na(TD) || is.na(TA) || is.na(Pr)) {
    return(NA_real_)
  }
  
  # Pressure is stored in Pa.
  # Convert pressure to hPa for the QV calculation.
  Pr_hPa <- Pr / 100
  
  # Calculate relative humidity
  RH <- 100 *
    (exp((17.625 * TD) / (243.04 + TD)) /
       exp((17.625 * TA) / (243.04 + TA)))
  
  # Calculate saturation vapor pressure
  rho_sat <- 6.112 *
    10^(17.67 * TA / (TA + 243.5))
  
  # Calculate saturation mixing ratio
  w_sat <- 0.6219907 *
    rho_sat /
    (rho_sat + Pr_hPa)
  
  # Calculate water vapor quantity
  Water_Vapor <- w_sat * RH
  
  return(Water_Vapor)
}

# Apply the function to each row and create a new column 'QV'
merged_data$QV <- mapply(
  calculate_water_vapor,
  merged_data$TD,
  merged_data$TA,
  merged_data$Pr,
  SIMPLIFY = TRUE
)

# Function to print data quality summary
print_data_quality_summary <- function(data, prefix = "Before") {
  
  total_hours <- nrow(data)
  
  missing_summary <- c(
    TA = sum(is.na(data$TA)),
    TD = sum(is.na(data$TD)),
    Pr = sum(is.na(data$Pr)),
    WS = sum(is.na(data$WS)),
    WD = sum(is.na(data$WD)),
    QV = sum(is.na(data$QV))
  )
  
  cat(sprintf(
    "---------Data Quality Summary (%s Filling)---------\n",
    prefix
  ))
  
  for (param in names(missing_summary)) {
    
    cat(sprintf(
      "Total Missing Hours for %s = %d (%0.2f%%)\n",
      param,
      missing_summary[param],
      (missing_summary[param] / total_hours) * 100
    ))
  }
}

# Print Data Quality Summary before filling
print_data_quality_summary(
  merged_data,
  "Before"
)

# Forward-fill and backward-fill missing values
filled_data <- merged_data %>%
  arrange(date) %>%
  mutate(
    across(
      c(TA, TD, WS, Pr, WD, QV),
      ~ na.locf(., na.rm = FALSE)
    )
  ) %>%
  mutate(
    across(
      c(TA, TD, WS, Pr, WD, QV),
      ~ na.fill(., "extend")
    )
  )

# Print Data Quality Summary after filling
print_data_quality_summary(
  filled_data,
  "After"
)

# Convert TA from Celsius to Kelvin
filled_data$TA <- filled_data$TA + 273.15

# Remove the 'TD' column from the final data
filled_data <- filled_data %>%
  select(-TD)

# Save the final filled data without 'TD'
output_file_path <- file.path(output_dir,
                              paste0(metdataID, "-", start_year, "-", # the year is included  here
                                     num_years, "-filled.csv"))
tryCatch({
  write.csv(filled_data, file = output_file_path, row.names = FALSE)
  cat(sprintf("Final filled data saved to %s\n", output_file_path))
}, error = function(e) {
  cat("Error saving the file:", e$message, "\n")
})
