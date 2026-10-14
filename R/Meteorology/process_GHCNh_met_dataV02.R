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
# O'Hare Airport:
# USW00094846

# Select station and years
metdataID <- "USW00094846"
start_year <- 2025
end_year <- 2025

years <- start_year:end_year

# Create output directory
output_dir <- file.path("Output/Data/GHCNh", metdataID)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Initialize list
data_list <- list()

# Download raw GHCNh observations
for (iYear in years) {
  
  cat("Downloading GHCNh:", metdataID, iYear, "\n")
  
  InputData <- tryCatch(
    worldmet::import_ghcn_hourly(
      station = metdataID,
      year = iYear,
      source = "psv",
      hourly = FALSE,
      extra = TRUE,
      abbr_names = TRUE
    ),
    error = function(e) {
      cat(
        "Error downloading year",
        iYear, ":", e$message, "\n"
      )
      NULL
    }
  )
  
  if (is.null(InputData) || nrow(InputData) == 0) {
    next
  }
  
  # Extract meteorological variables
  Met_Data <- InputData %>%
    transmute(
      date = as.POSIXct(date, tz = "UTC"),
      TA = as.numeric(air_temp),
      TD = as.numeric(dew_point),
      Pr = as.numeric(sea_pres),
      WS = as.numeric(ws),
      WD = as.numeric(wd)
    ) %>%
    filter(!is.na(date))
  
  # Replace non-finite values with NA
  Met_Data <- Met_Data %>%
    mutate(
      across(
        c(TA, TD, Pr, WS, WD),
        ~ replace(., !is.finite(.), NA_real_)
      )
    )
  
  data_list[[as.character(iYear)]] <- Met_Data
  
  cat("Observations imported:", nrow(Met_Data), "\n")
}

# Check downloaded data
if (length(data_list) == 0) {
  stop("No GHCNh observations were downloaded.")
}

# Combine observations
combined_data <- bind_rows(data_list) %>%
  arrange(date)

# Select observations near the following hour
selected_data <- combined_data %>%
  mutate(
    minute = as.integer(format(date, "%M", tz = "UTC")),
    second = as.integer(format(date, "%S", tz = "UTC"))
  ) %>%
  filter(
    minute >= 50 | (minute == 0 & second == 0)
  ) %>%
  mutate(
    date_hour = as.POSIXct(
      floor(as.numeric(date) / 3600) * 3600,
      origin = "1970-01-01",
      tz = "UTC"
    ),
    date_hour = if_else(
      minute >= 50,
      date_hour + 3600,
      date_hour
    )
  )

# Select one observation per hour
# This approximates ISD-Lite hourly selection.
# NOAA's full quality-ranking procedure is not reproduced.

hourly_data <- selected_data %>%
  mutate(
    time_difference = abs(
      as.numeric(
        difftime(date_hour, date, units = "secs")
      )
    )
  ) %>%
  group_by(date_hour) %>%
  arrange(time_difference, .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  transmute(
    date = date_hour,
    TA = TA,
    TD = TD,
    Pr = Pr,
    WS = WS,
    WD = WD
  ) %>%
  arrange(date)

# Define requested start date
start_date <- as.POSIXct(
  paste0(start_year, "-01-01 00:00:00"), tz = "UTC")

# Define requested end date
requested_end_date <- as.POSIXct(
  paste0(end_year, "-12-31 23:00:00"), tz = "UTC")

# Identify last available observation
last_observation <- max(hourly_data$date, na.rm = TRUE)

# Do not extend beyond last available observation
end_date <- min(requested_end_date, last_observation)

# Generate complete hourly sequence
all_hours <- seq(from = start_date, to = end_date, by = "hour")

# Merge selected observations with hourly sequence
validation_data <- data.frame(
  date = all_hours
) %>%
  left_join(hourly_data, by = "date")

# Calculate water-vapor mixing ratio (kg/kg)
calculate_water_vapor <- function(TD, Pr) {
  
  if (is.na(TD) || is.na(Pr)) {
    return(NA_real_)
  }
  
  # Vapor pressure from dew point (hPa)
  e <- 6.112 * exp(
    (17.67 * TD) / (TD + 243.5)
  )
  
  # Water-vapor mixing ratio (kg/kg)
  QV <- 0.62198 * e / (Pr - e)
  
  return(QV)
}

# Calculate QV for validation data
validation_data$QV <- mapply(
  calculate_water_vapor,
  validation_data$TD,
  validation_data$Pr,
  SIMPLIFY = TRUE
)

# Data quality summary before filling
cat("\nData Quality Summary (Before Filling)\n")

total_hours <- nrow(validation_data)

cat("Total hours:", total_hours, "\n")

for (variable in c("TA", "TD", "Pr", "WS", "WD", "QV")) {
  
  valid_hours <- sum(!is.na(validation_data[[variable]]))
  missing_hours <- sum(is.na(validation_data[[variable]]))
  
  missing_percent <- 100 * missing_hours / total_hours
  
  cat(sprintf(
    "%s - Valid: %d - Missing: %d (%.2f%%)\n",
    variable,
    valid_hours,
    missing_hours,
    missing_percent
  ))
}

# Check consecutive missing meteorological observations
# Function to calculate the longest consecutive NA period
max_missing_run <- function(x) {
  
  missing_runs <- rle(is.na(x))
  
  if (!any(missing_runs$values)) {
    return(0L)
  }
  
  max(missing_runs$lengths[missing_runs$values])
}

# Maximum acceptable consecutive missing hours
max_missing_hours <- 72

cat("\nConsecutive Missing Data Summary\n")
cat("-----------------------------------\n")

for (variable in c("TA", "TD", "Pr", "WS", "WD")) {
  
  longest_gap <- max_missing_run(validation_data[[variable]])
  
  cat(sprintf(
    "%s - Longest missing period: %d hours\n",
    variable,
    longest_gap
  ))
  
  if (longest_gap > max_missing_hours) {
    
    warning(sprintf(
      "%s contains more than %d consecutive missing hours.",
      variable,
      max_missing_hours
    ))
    
  }
}

# Fill missing meteorological observations
filled_data <- validation_data %>%
  arrange(date) %>%
  mutate(across(c(TA, TD, Pr, WS, WD), ~ zoo::na.locf(., na.rm = FALSE))
  ) %>%
  mutate(across(c(TA, TD, Pr, WS, WD),
                ~ zoo::na.locf(., fromLast = TRUE, na.rm = FALSE))
  )

# Recalculate QV using filled TD and pressure
filled_data$QV <- mapply(calculate_water_vapor, filled_data$TD,
                         filled_data$Pr, SIMPLIFY = TRUE)

# Data quality summary after filling
cat("\nData Quality Summary (After Filling)\n")

total_hours <- nrow(filled_data)

cat("Total hours:", total_hours, "\n")

for (variable in c("TA", "TD", "Pr", "WS", "WD", "QV")) {
  
  valid_hours <- sum(!is.na(filled_data[[variable]]))
  missing_hours <- sum(is.na(filled_data[[variable]]))
  
  missing_percent <- 100 * missing_hours / total_hours
  
  cat(sprintf(
    "%s - Valid: %d - Missing: %d (%.2f%%)\n",
    variable,
    valid_hours,
    missing_hours,
    missing_percent
  ))
}

# Convert temperature from Celsius to Kelvin
filled_data$TA <- filled_data$TA + 273.15

# Convert pressure from hPa to Pa
filled_data$Pr <- filled_data$Pr * 100

# Prepare final PUF-PAS meteorological data
filled_data <- filled_data %>%
  select(date, TA, Pr, WS, WD, QV)

# Display first observations
print(head(filled_data, 10))

# Display last observations
cat("\nLast observations:\n")
print(tail(filled_data))

# Save filled meteorological data
filled_file_path <- file.path(output_dir,
                              paste0(metdataID, "-", start_year, "-",
                                     end_year, "-GHCNh-filled.csv"))

write.csv(filled_data, file = filled_file_path, row.names = FALSE)

cat("\nFilled meteorological data saved to:\n")
cat(filled_file_path, "\n")
