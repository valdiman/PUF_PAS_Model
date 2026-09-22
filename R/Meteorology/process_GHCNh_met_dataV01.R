# Install packages --------------------------------------------------------
{
  install.packages("worldmet")
  install.packages("dplyr")
  install.packages("tidyr")
  install.packages("purrr")
}

# Load libraries ----------------------------------------------------------
{
  library(worldmet)
  library(dplyr)
  library(tidyr)
  library(purrr)
}

# Select station, years ---------------------------------------------------
# NOAA GHCNh:
# https://www.ncei.noaa.gov/access/search/datasets/global-historical-climatology-network-hourly/
#
# GHCNh station ID for Chicago Midway:
# USW00014819
metdataID <- "USW00014819"

# First and last year to download
start_year <- 2026
end_year <- 2026

years <- start_year:end_year

# Create output directory -----------------------------------------------
output_dir <- file.path("Output/Data/GHCNh", metdataID)

if (!dir.exists(output_dir)) {
  dir.create(
    output_dir,
    recursive = TRUE
  )
}

# Current calendar year --------------------------------------------------
current_year <- as.integer(
  format(Sys.Date(), "%Y")
)

# Initialize list --------------------------------------------------------
data_list <- list()

# Download and process GHCNh data ---------------------------------------
for (iYear in years) {
  
  cat("\nDownloading GHCNh:", metdataID, iYear, "\n")
  
  # Skip future years
  
  if (iYear > current_year) {
    
    cat(
      "Skipping year ",
      iYear,
      ": future year; data are not available yet.\n",
      sep = ""
    )
    
    next
  }
  
  # Download GHCNh hourly data
  
  InputData <- tryCatch(
    
    worldmet::import_ghcn_hourly(
      station = metdataID,
      year = iYear,
      source = "psv",
      hourly = TRUE,
      extra = TRUE,
      abbr_names = TRUE
    ),
    
    error = function(e) {
      
      cat("Could not download/process year ", iYear, ":\n", e$message,
          "\n", sep = "")
      
      return(NULL)
    }
  )
  
  # Skip year if download failed
  
  if (is.null(InputData)) {
    next
  }
  
  # Check whether data were returned
  
  if (nrow(InputData) == 0) {
    
    cat("No data returned for year ", iYear, ".\n", sep = "")
    
    next
  }
  
  # Display variable names the first time
  
  if (iYear == years[1]) {
    
    cat("\n")
    cat("Variables returned by GHCNh:\n")
    print(names(InputData))
    cat("\n")
  }
  
  # Select and rename variables
  #
  # GHCNh:
  #
  # air_temp  = air temperature (degrees C)
  # dew_point = dew point temperature (degrees C)
  # sea_pres  = sea-level pressure (hPa)
  # ws        = wind speed (m/s)
  # wd        = wind direction (degrees)
  #
  # We use sea-level pressure because this corresponds most
  # closely to the pressure variable used in your old ISD-Lite
  # workflow.
  
  Met_Data <- InputData %>%
    transmute(
      date = as.POSIXct(date, tz = "UTC"),
      
      # Temperature in degrees Celsius
      TA = as.numeric(air_temp),
      
      # Dew point in degrees Celsius
      TD = as.numeric(dew_point),
      
      # Sea-level pressure in hPa
      Pr_hPa = as.numeric(sea_pres),
      
      # Wind speed in m/s
      WS = as.numeric(ws),
      
      # Wind direction in degrees
      WD = as.numeric(wd)
    )
  
  # Convert non-finite values to NA

  Met_Data <- Met_Data %>%
    mutate(
      TA = ifelse(
        is.finite(TA),
        TA,
        NA_real_
      ),
      
      TD = ifelse(
        is.finite(TD),
        TD,
        NA_real_
      ),
      
      Pr_hPa = ifelse(
        is.finite(Pr_hPa),
        Pr_hPa,
        NA_real_
      ),
      
      WS = ifelse(
        is.finite(WS),
        WS,
        NA_real_
      ),
      
      WD = ifelse(
        is.finite(WD),
        WD,
        NA_real_
      )
    )
  
  # Store data
  
  data_list[[as.character(iYear)]] <- Met_Data
  
  
  cat("Observations imported:", nrow(Met_Data), "\n")
}

# Check that at least one year was successfully downloaded

if (length(data_list) == 0) {
  
  stop(
    "No GHCNh data were successfully downloaded. ",
    "Check the station ID, requested years, and internet connection."
  )
}

# Combine all years ------------------------------------------------------
combined_data <- bind_rows(data_list) %>%
  arrange(date)

# Remove duplicate timestamps --------------------------------------------
combined_data <- combined_data %>%
  distinct(date, .keep_all = TRUE)

# Define date range ------------------------------------------------------
start_date <- min(
  combined_data$date,
  na.rm = TRUE)

end_date <- max(
  combined_data$date,
  na.rm = TRUE)

# Display available data range -------------------------------------------

cat("\n")
cat("------------------------------------------------------------\n")
cat("Available GHCNh data range\n")
cat("------------------------------------------------------------\n")

cat("Start:", format(start_date, "%Y-%m-%d %H:%M", tz = "UTC"),
    "UTC\n")

cat("End:  ", format(end_date, "%Y-%m-%d %H:%M", tz = "UTC"), "UTC\n")

# Generate complete hourly sequence -------------------------------------
#
# IMPORTANT:
#
# This does NOT create future data.
#
# If NOAA currently has data through September 21, the sequence
# stops at September 21.
#
# Missing observations between the first and last available
# observations become NA after the left_join.

all_hours <- seq(from = start_date, to = end_date, by = "hour")

merged_data <- data.frame(
  date = all_hours
) %>%
  left_join(
    combined_data,
    by = "date"
  ) %>%
  arrange(date)

# Make sure missing values are NA ---------------------------------------
merged_data <- merged_data %>%
  mutate(
    TA = ifelse(
      is.finite(TA),
      TA,
      NA_real_
    ),
    
    TD = ifelse(
      is.finite(TD),
      TD,
      NA_real_
    ),
    
    Pr_hPa = ifelse(
      is.finite(Pr_hPa),
      Pr_hPa,
      NA_real_
    ),
    
    WS = ifelse(
      is.finite(WS),
      WS,
      NA_real_
    ),
    
    WD = ifelse(
      is.finite(WD),
      WD,
      NA_real_
    )
  )

# Calculate QV -----------------------------------------------------------
# QV is calculated only where TA, TD, and pressure are available.
# Pressure here is in hPa.

calculate_water_vapor <- function(
    TD,
    TA,
    Pr_hPa
) {
  
  # Return NA if any required variable is missing
  
  if (
    is.na(TD) ||
    is.na(TA) ||
    is.na(Pr_hPa)
  ) {
    
    return(NA_real_)
  }
  
  # Relative humidity
  
  RH <- 100 *
    (
      exp(
        (17.625 * TD) /
          (243.04 + TD)
      ) /
        exp(
          (17.625 * TA) /
            (243.04 + TA)
        )
    )
  
  # Saturation vapor pressure
  
  rho_sat <- 6.112 *
    10^(
      17.67 * TA /
        (TA + 243.5)
    )
  
  # Saturation mixing ratio
  
  w_sat <- 0.6219907 *
    rho_sat /
    (rho_sat + Pr_hPa)
  
  # Water vapor quantity
  
  Water_Vapor <- w_sat * RH
  
  return(Water_Vapor)
}

merged_data$QV <- mapply(
  calculate_water_vapor,
  merged_data$TD,
  merged_data$TA,
  merged_data$Pr_hPa
)

# Data quality summary ---------------------------------------------------

print_data_quality_summary <- function(data) {
  
  total_hours <- nrow(data)
  
  missing_summary <- c(
    
    TA = sum(
      is.na(data$TA)
    ),
    
    TD = sum(
      is.na(data$TD)
    ),
    
    Pr = sum(
      is.na(data$Pr_hPa)
    ),
    
    WS = sum(
      is.na(data$WS)
    ),
    
    WD = sum(
      is.na(data$WD)
    ),
    
    QV = sum(
      is.na(data$QV)
    )
  )
  
  cat("\n")
  cat("------------------------------------------------------------\n")
  cat("Data Quality Summary\n")
  cat("------------------------------------------------------------\n")
  
  cat(sprintf("Total Hours = %d\n", total_hours))
  
  for (param in names(missing_summary)) {
    
    cat(sprintf("Missing Hours for %s = %d (%0.2f%%)\n", param,
                missing_summary[param],
                100 * missing_summary[param] / total_hours))
  }
}

print_data_quality_summary(merged_data)

# NO FORWARD-FILL / BACKWARD-FILL ---------------------------------------
# Missing observations remain NA.
# We intentionally DO NOT use:
# na.locf()
# na.fill()
#
# Therefore:
#
# 18:00   3.2
# 19:00   3.5
# 20:00    NA
# 21:00    NA
# 22:00    NA

final_data <- merged_data %>%
  arrange(date)

# Convert pressure from hPa to Pa ----------------------------------------
# Final output retains pressure in Pa to be consistent with
# your previous dataset.
# 1 hPa = 100 Pa

final_data <- final_data %>%
  mutate(
    Pr = Pr_hPa * 100
  )

# Convert TA from Celsius to Kelvin --------------------------------------
final_data <- final_data %>%
  mutate(
    TA = TA + 273.15
  )

# Remove TD and temporary pressure column -------------------------------
final_data <- final_data %>%
  select(
    date,
    TA,
    Pr,
    WS,
    WD,
    QV
  )

# Display final data -----------------------------------------------------
print(head(final_data))

cat("\nLast observations:\n")

print(tail(final_data))

# Save -------------------------------------------------------------------
# The filename uses start_year and end_year.
# Example:
# USW00014819-2026-2026-GHCNh.csv
#
# or:
#
# USW00014819-2026-2027-GHCNh.csv

output_file_path <- file.path(output_dir,
                              paste0(metdataID, "-", start_year, "-",
                                     end_year, "-GHCNh.csv"))

tryCatch({
  
  write.csv(final_data, file = output_file_path, row.names = FALSE)
  
  cat("\n")
  cat("------------------------------------------------------------\n")
  cat("Final data saved successfully\n")
  cat("------------------------------------------------------------\n")
  
  cat(output_file_path, "\n")
  
}, error = function(e) {
  
  cat("\nError saving the file:\n", e$message, "\n")
  
})
