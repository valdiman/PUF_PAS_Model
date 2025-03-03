
# Calculations (functions) ------------------------------------------------
PUF_PAS_Effective_Volume_Calculations <- function(start_date, end_date, met_data_path, pcb_properties_path, pcb_ppLFER_path, file_path) {
  
  # Specify the method for determining KPUF (1 or 2)
  KPUFMethod <- 1
  
  # Known variables about PUF disk parameters
  diameter <- 0.14
  thickness <- 0.0135
  dpuf <- 21173
  As <- 0.0365
  
  # Calculate PUF parameters based on inputs
  VPUF <- pi * ((diameter^2) / 4) * thickness
  
  # Read in site-specific Met data
  Met_Data <- read.csv(met_data_path, header = TRUE)
  
  # Import PCB properties
  PCB_Properties <- read.csv(pcb_properties_path, header = TRUE)
  PCB_ppLFER <- read.csv(pcb_ppLFER_path, header = TRUE)
  
  # Convert the 'date' column in Met_Data to POSIXct format
  Met_Data$date <- as.POSIXct(Met_Data$date, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  
  # Now, find the closest start and end times
  StartTime <- which.min(abs(Met_Data$date - as.POSIXct(start_date, tz = "UTC")))
  EndTime <- which.min(abs(Met_Data$date - as.POSIXct(end_date, tz = "UTC")))
  
  # Length of deployment (number of time steps)
  Length <- EndTime - (StartTime - 1)
  
  # Read in Met variables for the above time series
  T <- Met_Data[StartTime:EndTime, 2]     # Temperature (Kelvin)
  P <- Met_Data[StartTime:EndTime, 3]     # Pressure (Pascals)
  WS <- Met_Data[StartTime:EndTime, 4]    # Wind Speed (m/s)
  Qvap <- Met_Data[StartTime:EndTime, 6]  # Water-Vapor Mixing Ratio (kg/kg)
  
  # Prepare deployment-specific meteorological data for output
  DeploymentMetData <- Met_Data[StartTime:EndTime, ]
  
  # Internal flowrate and wind speed exceedance calculation
  InternalFlowrate <- function(WS) {
    Vi <- rep(0, length(WS))
    WScount <- 0
    for (t in 1:length(WS)) {
      if (WS[t] <= 0.9) {
        Vi[t] <- 0
      } else {
        Vi[t] <- 0.3620 * WS[t] - 0.313
        if (WS[t] > 5) {
          WScount <- WScount + 1
        }
      }
    }
    WS_Exceedence <- WScount / length(Vi) * 100
    return(list(Vi = Vi, WS_Exceedence = WS_Exceedence))
  }
  
  result <- InternalFlowrate(WS)
  Vi <- result$Vi
  WS_Exceedence <- result$WS_Exceedence
  
  # Calculate average values for ViGamma and TGamma
  ViGamma <- mean(Vi)
  TGamma <- mean(T)
  
  # Function to calculate GammaPCB
  GammaPCBCalculation <- function(ViGamma, TGamma, LKOA, LKOA28) {
    Gamma28 <- -0.153 + 0.077 * ViGamma + 0.000668 * TGamma - 0.000310 * ViGamma * TGamma
    GammaPCB <- Gamma28 * (LKOA / LKOA28)
    return(GammaPCB)
  }
  
  # Function to calculate PCB diffusivity
  PCBDiffusivity <- function(T, P, mm) {
    VH2O <- 9.5
    VAir <- 20.1
    mH2O <- 18.015
    mAir <- 28.97
    
    D <- (((10^-3 * T^1.75 * ((1 / mAir) + (1 / mH2O))^0.5) / 
             (P * (1 / 101325) * (VAir^(1 / 3) + VH2O^(1 / 3))^2)) * 
            ((mm / mH2O)^-0.5)) / 100^2
    
    return(D)
  }
  
  # Function to calculate kinematic viscosity (m^2/s)
  Viscosity <- function(T, Qvap, P) {
    Za <- 0.038474
    Tca <- 132.206
    Zcw <- 0.231
    Zw <- 0.0192
    Tcw <- 647.4
    Rd <- 287.058
    Rv <- 461.495
    mH2O <- 18.015
    mAir <- 28.97
    
    MuAir <- (17.78 * ((4.58 * (T / Tca) - 1.67)^0.625) * 10^-7) / Za
    MuWater <- ((7.55 * (T / Tcw) - 0.55) * (Zcw^-1.25) * 10^-7) / Zw
    a <- ifelse(T >= 293.15, 2.5, 3.5)
    Mw <- Qvap * (1 / mH2O) * 1000 * (P / (Rd * T))
    Ma <- (1 / Qvap) * (1 / mAir) * 1000 * 1000
    Xw <- Mw / (Mw + Ma)
    Xa <- Ma / (Mw + Ma)
    DynamicMu <- (Xa * MuAir + Xw * MuWater) * (1 + ((Xw - Xw^2) / a))
    Pv <- Xw * P
    Pd <- Xa * P
    Density <- (Pd / (Rd * T)) + (Pv / (Rv * T))
    Kinematic <- DynamicMu / Density
    
    return(Kinematic)
  }
  
  # Function to calculate mass transfer rate
  MassTransfer <- function(Vi, Kinematic, GammaPCB, D, diameter) {
    Beta <- 1 / 3
    alpha <- ifelse(Vi < 0.5, 0.5, 0.9)
    Nu <- Kinematic^(Beta - alpha)
    kv <- GammaPCB * (D^(1 - Beta)) * (Vi^alpha) * Nu * (diameter^(alpha - 1))
    return(kv)
  }
  
  # Function to calculate KPUF
  KPUFCalculation <- function(LKOA, dU, T, method, Congener_ppLFER) {
    if (method == 1) {
      Rg <- 8.3144  # Gas constant in J/mol*K
      
      # Adjust LKOA by temperature
      LKOAi <- LKOA - (dU / (2.303 * Rg)) * ((1 / T) - (1 / 298.15))
      
      # Calculate PUF/Air equilibrium partition coefficient
      KPUF <- 10^(0.6366 * LKOAi - 3.1774)
      
    } else if (method == 2) {
      cs <- -1.279
      ch <- -354.607
      es <- 0.449
      eh <- 179.41
      ss <- -0.745
      sh <- -692.187
      as <- -2.541
      ah <- -1683.56
      bs <- -0.118
      bh <- -33.83
      ls <- -0.456
      lh <- -365.896
      
      E <- Congener_ppLFER[2]  # Assuming correct index for descriptor
      S <- Congener_ppLFER[3]
      A <- Congener_ppLFER[4]
      B <- Congener_ppLFER[5]
      L <- Congener_ppLFER[7]
      
      # Calculate logKPUF using the Abraham model
      logKPUF <- (cs - (ch / T)) + (es - (eh / T)) * E + (ss - (sh / T)) * S + 
        (as - (ah / T)) * A + (bs - (bh / T)) * B + (ls - (lh / T)) * L
      
      # Calculate KPUF (m^3/g)
      KPUF <- 10^logKPUF / 1000000
    }
    
    return(KPUF)
  }
  
  # Create zero array for deployment length and all PCBs
  numPCB <- nrow(PCB_Properties)
  PAS_Array <- array(0, dim = c(Length, numPCB, 5))
  
  for (C in 1:numPCB) {
    for (t in 1:Length) {
      mm <- PCB_Properties[C, 2]
      dU <- PCB_Properties[C, 3]
      LKOA <- PCB_Properties[C, 4]
      Congener_ppLFER <- PCB_ppLFER[C, ]
      
      GammaPCB <- GammaPCBCalculation(ViGamma, TGamma, LKOA, PCB_Properties[28, 4])
      D <- PCBDiffusivity(T[t], P[t], mm)
      Kinematic <- Viscosity(T[t], Qvap[t], P[t])
      kv <- MassTransfer(Vi[t], Kinematic, GammaPCB, D, diameter)
      Rs <- kv * As * 86400
      KPUF <- KPUFCalculation(LKOA, dU, T[t], KPUFMethod, Congener_ppLFER) * dpuf
      
      if (t == 1) {
        Veff <- (kv * 3600) * As / VPUF * (VPUF - (0 / KPUF))
      } else {
        Veff <- (kv * 3600) * As / VPUF * (VPUF - (PAS_Array[t - 1, C, 5] / KPUF))
      }
      
      PAS_Array[t, C, 1] <- Rs
      PAS_Array[t, C, 2] <- kv
      PAS_Array[t, C, 3] <- KPUF
      PAS_Array[t, C, 4] <- Veff
      
      if (t == 1) {
        PAS_Array[t, C, 5] <- Veff
      } else {
        PAS_Array[t, C, 5] <- Veff + PAS_Array[t - 1, C, 5]
      }
    }
  }
  
  # Create matrix of all variables for each congener
  PAS_Final <- matrix(0, nrow = 2, ncol = numPCB)
  for (C in 1:numPCB) {
    RsAVG <- mean(PAS_Array[, C, 1])
    Veff_Final <- PAS_Array[Length, C, 5]
    PAS_Final[1, C] <- Veff_Final
    PAS_Final[2, C] <- RsAVG
  }
  
  formatted_start_date <- format(as.POSIXct(start_date), "%Y%m%d%H")
  formatted_end_date <- format(as.POSIXct(end_date), "%Y%m%d%H")
  
  rowID <- matrix(nrow = 2, ncol = 6)
  rowID[1, ] <- c('1', formatted_start_date, formatted_end_date, as.character(Length), as.character(WS_Exceedence), 'Veff')
  rowID[2, ] <- c('1', formatted_start_date, formatted_end_date, as.character(Length), as.character(WS_Exceedence), 'SR')
  
  outData <- cbind(rowID, PAS_Final)
  
  column_names <- c("PUF_ID", "Deployment", "Collection", "Length", "WS_Exceedence", "Type", PCB_Properties$Congener.s..ID)
  colnames(outData) <- column_names
  
  # Create the directory if it does not exist
  dir.create(dirname(file_path), recursive = TRUE)
  
  # Save the data frame to a CSV file
  write.csv(outData, file = file_path, row.names = FALSE)
}

# Run the Model -----------------------------------------------------------
PUF_PAS_Effective_Volume_Calculations(
  start_date = "2018-12-01 01:00:00", 
  end_date = "2019-01-10 01:00:00", 
  # Need to select the folder and name of the file where the met data is stored
  met_data_path = "Output/Data/isd_light/725300-94846/725300-94846-2018-2-filled.csv", 
  pcb_properties_path = "Data/PCB_Properties_MW_DU_KOA.csv", 
  pcb_ppLFER_path = "Data/PCB_LFER_descriptors.csv", 
  # Need to add the folder where the result is going to be saved
  # It should be metdataID-year
  file_path = "Output/Data/Results/isd_light/VefOHareAirport2018-2020.csv"
)
