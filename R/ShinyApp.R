# Install necessary packages if you haven't already
# install.packages("shiny")
# install.packages("nasapower")
# install.packages("dplyr")
# install.packages("zoo")

# Load necessary libraries
library(shiny)
library(nasapower)
library(dplyr)
library(zoo)

# Define UI for the application
ui <- fluidPage(
  # Application title
  titlePanel("Weather Data Downloader"),
  
  # Sidebar layout
  sidebarLayout(
    sidebarPanel(
      # Latitude and Longitude input
      textInput("longitude", "Enter Longitude:", value = "-87.904722"),
      textInput("latitude", "Enter Latitude:", value = "41.978611"),
      
      # Start and End date input
      textInput("start_date", "Enter Start Date (YYYY-MM-DD):", value = "2018-01-01"),
      textInput("end_date", "Enter End Date (YYYY-MM-DD):", value = "2020-12-31"),
      
      # Submit button
      actionButton("submit", "Download Data")
    ),
    
    mainPanel(
      # Display data summary
      h3("Data Preview:"),
      tableOutput("data_preview")
    )
  )
)

# Define server logic
server <- function(input, output) {
  
  observeEvent(input$submit, {
    # Get coordinates from input
    lonlat <- c(as.numeric(input$longitude), as.numeric(input$latitude))
    
    # Get the start and end dates from input
    start_date <- input$start_date
    end_date <- input$end_date
    
    # Download data from NASA Power API
    test_data <- get_power(
      community = "AG",  # Agriculture data
      pars = c("T2M", "T2MDEW", "PS", "WD10M", "WS10M"),  # Add all required parameters
      temporal_api = "hourly",  # Hourly data
      lonlat = lonlat,  # Coordinates from user input
      dates = c(start_date, end_date),  # Date range from user input
      time_standard = "UTC"  # Use UTC time
    )
    
    # Format the data
    date <- as.POSIXct(paste(test_data$YEAR, sprintf("%02d", test_data$MO), 
                             sprintf("%02d", test_data$DY), 
                             sprintf("%02d", test_data$HR), sep = "-"), 
                       format = "%Y-%m-%d-%H", tz = "UTC")
    
    Met_Data <- data.frame(
      date = date,
      T2M = test_data$T2M,         # Temperature (Celsius)
      T2MDEW = test_data$T2MDEW,   # Dew point (Celsius)
      PS = 1000 * test_data$PS,    # Pressure (Pascals)
      WD10M = test_data$WD10M,     # Wind direction (degrees)
      WS10M = test_data$WS10M      # Wind speed (m/s)
    )
    
    # Calculate water vapor (QV)
    calculate_water_vapor <- function(TD, TA, Pr) {
      RH <- 100 * (exp((17.625 * TD) / (243.04 + TD)) / exp((17.625 * TA) / (243.04 + TA)))
      rho_sat <- 6.112 * 10^(17.67 * TA / (TA + 243.5))
      w_sat <- 0.6219907 * rho_sat / (rho_sat + Pr)
      Water_Vapor <- w_sat * RH
      return(Water_Vapor)
    }
    
    Met_Data$QV <- mapply(calculate_water_vapor, Met_Data$T2MDEW, Met_Data$T2M, Met_Data$PS)
    
    # Replace missing values with NA
    missing_values <- list(T2M = -999.9, T2MDEW = -999.9, WS10M = -999.9, PS = -99990, WD10M = -9999)
    Met_Data <- Met_Data %>%
      mutate(
        T2M = replace(T2M, T2M == missing_values$T2M, NA),
        T2MDEW = replace(T2MDEW, T2MDEW == missing_values$T2MDEW, NA),
        WS10M = replace(WS10M, WS10M == missing_values$WS10M, NA),
        PS = replace(PS, PS == missing_values$PS, NA),
        WD10M = replace(WD10M, WD10M == missing_values$WD10M, NA)
      )
    
    # Forward-fill and backward-fill missing values
    filled_data <- Met_Data %>%
      arrange(date) %>%
      mutate(across(c(T2M, T2MDEW, WS10M, PS, WD10M, QV), ~ na.locf(., na.rm = FALSE))) %>%
      mutate(across(c(T2M, T2MDEW, WS10M, PS, WD10M, QV), ~ na.fill(., "extend")))
    
    # Convert T2M from Celsius to Kelvin
    filled_data$T2M <- filled_data$T2M + 273.15
    
    # Remove the 'T2MDEW' column from the final data
    filled_data <- filled_data %>% select(-T2MDEW)
    
    # Rename columns to match the desired format
    filled_data <- filled_data %>%
      rename(
        TA = T2M,
        Pr = PS,
        WS = WS10M,
        WD = WD10M
      ) %>%
      select(date, TA, Pr, WS, WD, QV)  # Ensure the correct column order
    
    # Output data preview
    output$data_preview <- renderTable({
      head(filled_data)  # Display first few rows of the data
    })
    
    # Create output directory and save the file
    output_dir <- "Output/Data/MERRA"
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
    output_file_path <- file.path(output_dir, paste0("WeatherData-", gsub("-", "", Sys.Date()), ".csv"))
    
    # Save the final filled data
    tryCatch({
      write.csv(filled_data, file = output_file_path, row.names = FALSE)
      cat(sprintf("Final filled data saved to %s\n", output_file_path))
    }, error = function(e) {
      cat("Error saving the file:", e$message, "\n")
    })
  })
}

# Run the application
shinyApp(ui = ui, server = server)
