
# Install packages --------------------------------------------------------
{
  install.packages("worldmet")
  install.packages("dplyr")
  install.packages("tidyr")
  install.packages("zoo")
}
  
# Load libraries ----------------------------------------------------------
{
  library(worldmet)
  library(dplyr)
  library(tidyr)
  library(zoo)
}

# Select station, years ---------------------------------------------------
# GHCNh station ID for Chicago Midway:
# USW00014819

metdataID <- "USW00014819"

start_year <- 2026
num_years <- 1

years <- start_year:(start_year + num_years - 1)

# Create output directory -----------------------------------------------
output_dir <- file.path("Output/Data/isd_light", metdataID)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Initialize list --------------------------------------------------------
data_list <- list()

# Download and process GHCNh data ---------------------------------------
for (i in seq_along(years)) {
  
  iYear <- years[i]
  
  cat("Downloading GHCNh:", metdataID, iYear, "\n")
  
  # Import GHCNh hourly data
  InputData <- worldmet::import_ghcn_hourly(
    station = metdataID,
    year = iYear,
    source = "psv",
    hourly = TRUE,
    extra = FALSE,
    abbr_names = TRUE
  )
  
  # Examine names if needed
  # print(names(InputData))
  
  # Select variables and rename them to match your old workflow
  Met_Data <- InputData %>%
    transmute(
      date = date,
      TA = air_temp,
      TD = dew_point,
      Pr = atmos_pres,
      WS = ws,
      WD = wd
    )
  
  # Store data
  data_list[[i]] <- Met_Data
}

# Combine all years ------------------------------------------------------
combined_data <- bind_rows(data_list)

# Sort by date
combined_data <- combined_data %>%
  arrange(date)

# Define date range ------------------------------------------------------
start_date <- min(combined_data$date, na.rm = TRUE)
end_date <- max(combined_data$date, na.rm = TRUE)

# Generate complete hourly sequence -------------------------------------
all_hours <- seq(
  from = start_date,
  to = end_date,
  by = "hour"
)

merged_data <- data.frame(date = all_hours) %>%
  left_join(combined_data, by = "date")

# Make sure missing values are NA ---------------------------------------
merged_data <- merged_data %>%
  mutate(
    TA = ifelse(is.finite(TA), TA, NA_real_),
    TD = ifelse(is.finite(TD), TD, NA_real_),
    WS = ifelse(is.finite(WS), WS, NA_real_),
    Pr = ifelse(is.finite(Pr), Pr, NA_real_),
    WD = ifelse(is.finite(WD), WD, NA_real_)
  )

# Calculate QV -----------------------------------------------------------

calculate_water_vapor <- function(TD, TA, Pr) {
  
  # Return NA when any required variable is missing
  if (is.na(TD) || is.na(TA) || is.na(Pr)) {
    return(NA_real_)
  }
  
  RH <- 100 *
    (
      exp((17.625 * TD) / (243.04 + TD)) /
        exp((17.625 * TA) / (243.04 + TA))
    )
  
  rho_sat <- 6.112 *
    10^(17.67 * TA / (TA + 243.5))
  
  w_sat <- 0.6219907 *
    rho_sat /
    (rho_sat + Pr)
  
  Water_Vapor <- w_sat * RH
  
  return(Water_Vapor)
}

merged_data$QV <- mapply(
  calculate_water_vapor,
  merged_data$TD,
  merged_data$TA,
  merged_data$Pr
)

# Data quality summary ---------------------------------------------------

print_data_quality_summary <- function(data,
                                       prefix = "Before") {
  
  total_hours <- nrow(data)
  
  missing_summary <- c(
    TA = sum(is.na(data$TA)),
    TD = sum(is.na(data$TD)),
    WS = sum(is.na(data$WS)),
    Pr = sum(is.na(data$Pr)),
    WD = sum(is.na(data$WD)),
    QV = sum(is.na(data$QV))
  )
  
  cat(
    sprintf(
      "--------- Data Quality Summary (%s Filling) ---------\n",
      prefix
    )
  )
  
  for (param in names(missing_summary)) {
    
    cat(
      sprintf(
        "Missing Hours for %s = %d (%0.2f%%)\n",
        param,
        missing_summary[param],
        100 * missing_summary[param] / total_hours
      )
    )
  }
}

print_data_quality_summary(
  merged_data,
  "Before"
)

# Forward-fill and backward-fill ----------------------------------------
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

# Convert temperature from Celsius to Kelvin ----------------------------
filled_data$TA <- filled_data$TA + 273.15

# Remove TD --------------------------------------------------------------
filled_data <- filled_data %>%
  select(-TD)

# Save -------------------------------------------------------------------
output_file_path <- file.path(output_dir, paste0(metdataID, "-", start_year,
                                                 "-", num_years, "-filled.csv"))

write.csv(filled_data, file = output_file_path, row.names = FALSE)

cat(sprintf("Final filled data saved to %s\n", output_file_path))

