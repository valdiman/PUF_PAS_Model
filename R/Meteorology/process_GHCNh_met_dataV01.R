#
# Install packages
{
  install.packages("worldmet")
  install.packages("dplyr")
  install.packages("tidyr")
  install.packages("zoo")
}

# Load libraries
{
  library(worldmet)
  library(dplyr)
  library(tidyr)
  library(zoo)
}

# Select station and period
#
# NOAA GHCNh:
# https://www.ncei.noaa.gov/access/search/datasets/global-historical-climatology-network-hourly/
#
# Chicago Midway:
# USW00014819

metdataID <- "USW00014819"

# Choose the period mode:
# period_year
# "full_year" = use complete calendar years
# "end_date"  = stop at a specific year/month/day

period_mode <- "end_date"

# First year to process
start_year <- 2026

# Last year to process
end_year <- 2026

# Used only when period_mode = "end_date"
end_month <- 9
end_day <- 19

years <- start_year:end_year

# Current calendar year
current_year <- as.integer(
  format(Sys.Date(), "%Y")
)

# Requested end date
if (period_mode == "end_date") {
  
  requested_end_date <- as.POSIXct(
    sprintf(
      "%04d-%02d-%02d 23:00:00",
      end_year,
      end_month,
      end_day
    ),
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  
} else if (period_mode == "full_year") {
  
  requested_end_date <- as.POSIXct(
    sprintf(
      "%04d-12-31 23:00:00",
      end_year
    ),
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  
} else {
  
  stop("period_mode must be either 'full_year' or 'end_date'.")
}

cat("\nRequested period mode:", period_mode, "\n")

cat("Requested end date:", format(requested_end_date, "%Y-%m-%d %H:%M:%S",
                                  tz = "UTC"), "UTC\n")

# Create output directory
output_dir <- file.path("Output/Data/GHCNh", metdataID)

if (!dir.exists(output_dir)) {
  dir.create(
    output_dir,
    recursive = TRUE
  )
}

# Initialize list
data_list <- list()

# Download and process GHCNh data
for (iYear in years) {
  
  cat("\n")
  cat("Downloading GHCNh data\n")
  cat("Station:", metdataID, "\n")
  cat("Year:", iYear, "\n")
  
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
      
      cat(
        "\nERROR downloading/processing year ",
        iYear,
        ":\n",
        e$message,
        "\n",
        sep = ""
      )
      
      return(NULL)
    }
  )
  
  # Skip year if download failed
  if (is.null(InputData)) {
    
    cat(
      "Skipping year ",
      iYear,
      ".\n",
      sep = ""
    )
    
    next
  }
  
  # Check whether data were returned
  if (nrow(InputData) == 0) {
    
    cat(
      "No observations returned for year ",
      iYear,
      ".\n",
      sep = ""
    )
    
    next
  }
  
  # Show variables returned by GHCNh
  if (iYear == years[1]) {
    
    cat("\n")
    cat("Variables returned by GHCNh:\n")
    print(
      names(InputData)
    )
    cat("\n")
  }
  
  # Select variables and rename them
  #
  # date       = UTC date/time
  # air_temp   = air temperature, degrees C
  # dew_point  = dew-point temperature, degrees C
  # sea_pres   = sea-level pressure, hPa
  # ws         = wind speed, m/s
  # wd         = wind direction, degrees
  
  Met_Data <- InputData %>%
    transmute(
      
      date = as.POSIXct(
        date,
        tz = "UTC"
      ),
      
      TA = as.numeric(
        air_temp
      ),
      
      TD = as.numeric(
        dew_point
      ),
      
      Pr_hPa = as.numeric(
        sea_pres
      ),
      
      WS = as.numeric(
        ws
      ),
      
      WD = as.numeric(
        wd
      )
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
  
  # Store year
  data_list[[as.character(iYear)]] <- Met_Data
  
  cat(
    "Observations imported:",
    nrow(Met_Data),
    "\n"
  )
}

# Check that data were downloaded
if (length(data_list) == 0) {
  
  stop(
    "ERROR: No GHCNh data were downloaded."
  )
  
} else {
  
  cat("\n")
  cat("GHCNh DOWNLOAD COMPLETE\n")
  cat("Station:", metdataID, "\n")
  cat("Years:", paste(years, collapse = ", "), "\n")
  cat("Years successfully imported:", length(data_list), "\n")
}

# Combine all years
combined_data <- bind_rows(
  data_list
) %>%
  arrange(date)

# Remove duplicate timestamps
combined_data <- combined_data %>%
  distinct(date, .keep_all = TRUE)

# Define the actual start date
start_date <- min(combined_data$date, na.rm = TRUE)

# Determine the actual end date
#
# In full_year mode:
#   use the requested end of the selected year.
#
# In end_date mode:
#   first limit to the requested date,
#   then find the last timestamp with an actual observation.
#
if (period_mode == "full_year") {
  
  actual_end_date <- requested_end_date
  
} else {
  
  requested_data <- combined_data %>%
    filter(
      date <= requested_end_date
    )
  
  reported_data <- requested_data %>%
    filter(
      !is.na(TA) |
        !is.na(TD) |
        !is.na(Pr_hPa) |
        !is.na(WS) |
        !is.na(WD)
    )
  
  if (nrow(reported_data) == 0) {
    
    stop(
      "No actual GHCNh observations exist within the requested period."
    )
  }
  
  actual_end_date <- max(
    reported_data$date,
    na.rm = TRUE
  )
}

# Keep only the requested period
combined_data <- combined_data %>%
  filter(date <= actual_end_date)

# Display actual data range
cat("\n")
cat("DATA RANGE\n")

cat("Start:", format(start_date, "%Y-%m-%d %H:%M", tz = "UTC"),
    "UTC\n")
cat("End:", format(actual_end_date, "%Y-%m-%d %H:%M", tz = "UTC"),
    "UTC\n")

# Generate complete hourly sequence
all_hours <- seq(from = start_date, to = actual_end_date, by = "hour")

merged_data <- data.frame(
  date = all_hours
) %>%
  left_join(
    combined_data,
    by = "date"
  ) %>%
  arrange(date)

# Make sure missing values are represented by NA
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

# Calculate QV
calculate_water_vapor <- function(
    TD,
    TA,
    Pr_hPa
) {
  
  if (
    is.na(TD) ||
    is.na(TA) ||
    is.na(Pr_hPa)
  ) {
    
    return(NA_real_)
  }
  
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
  
  rho_sat <- 6.112 *
    10^(
      17.67 * TA /
        (TA + 243.5)
    )
  
  w_sat <- 0.6219907 *
    rho_sat /
    (
      rho_sat +
        Pr_hPa
    )
  
  Water_Vapor <- w_sat * RH
  
  return(
    Water_Vapor
  )
}

merged_data$QV <- mapply(
  calculate_water_vapor,
  merged_data$TD,
  merged_data$TA,
  merged_data$Pr_hPa,
  SIMPLIFY = TRUE
)

# Data quality summary before filling
print_data_quality_summary <- function(
    data) {
  
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
  cat("DATA QUALITY SUMMARY - BEFORE FILLING\n")
  
  cat(
    sprintf(
      "Total Hours = %d\n",
      total_hours
    )
  )
  
  for (param in names(missing_summary)) {
    
    cat(
      sprintf(
        "Missing Hours for %s = %d (%0.2f%%)\n",
        param,
        missing_summary[param],
        100 *
          missing_summary[param] /
          total_hours
      )
    )
  }
}

print_data_quality_summary(merged_data)

# Fill missing observations
#
# This fills gaps only within the selected data range.
#
# In end_date mode, the data range already stops at the last actual
# GHCNh observation, so future/unreported dates are never filled.

filled_data <- merged_data %>%
  arrange(date) %>%
  mutate(across(c(TA, TD, WS, Pr_hPa, WD, QV), ~ na.locf(., na.rm = FALSE))
  ) %>%
  mutate(across(c(TA, TD, WS, Pr_hPa, WD, QV), ~ na.fill(., "extend")))

# Data quality summary after filling
cat("\n")
cat("DATA QUALITY SUMMARY - AFTER FILLING\n")

cat("Remaining missing TA:     ", sum(is.na(filled_data$TA)), "\n",
    sep = "")

cat("Remaining missing TD:     ", sum(is.na(filled_data$TD)), "\n",
    sep = "")

cat("Remaining missing Pr_hPa: ", sum(is.na(filled_data$Pr_hPa)), "\n",
    sep = "")

cat("Remaining missing WS:     ",sum(is.na(filled_data$WS)), "\n",
    sep = "")

cat("Remaining missing WD:     ", sum(is.na(filled_data$WD)), "\n",
    sep = "")

cat("Remaining missing QV:     ", sum(is.na(filled_data$QV)), "\n",
    sep = "")

# Convert pressure from hPa to Pa
filled_data <- filled_data %>%
  mutate(
    Pr = Pr_hPa * 100
  )

# Convert TA from Celsius to Kelvin
filled_data <- filled_data %>%
  mutate(TA = TA + 273.15)

# Remove TD and temporary pressure column
filled_data <- filled_data %>%
  select(date, TA, Pr, WS, WD, QV)

# Display final data range
cat("\n")
cat("FINAL DATASET\n")

cat("First record:", format(min(filled_data$date), "%Y-%m-%d %H:%M",
                            tz = "UTC"), "UTC\n")

cat("Last record:", format(max(filled_data$date), "%Y-%m-%d %H:%M",
                           tz = "UTC"), "UTC\n")

cat("Number of records:", nrow(filled_data), "\n")

cat("\nLast records:\n")

print(tail(filled_data))

# Save final data
output_file_path <- file.path(output_dir,
                              paste0(metdataID, "-", start_year, "-",
                                     end_year, "-GHCNh-filled.csv"))

tryCatch({
  
  write.csv(filled_data, file = output_file_path, row.names = FALSE)
  
  cat("\n")
  cat("FINAL DATA SAVED SUCCESSFULLY\n")
  cat(output_file_path, "\n")
  
}, error = function(e) {
  
  cat("\nERROR SAVING FILE:\n", e$message, "\n")
})

