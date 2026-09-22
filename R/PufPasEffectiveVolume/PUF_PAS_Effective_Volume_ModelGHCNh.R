## Uses NOAA GHCNh data generated from:
# R/Meteorology/process_GHCNh_dataV01.R
#
# Need to select the dates of the PUF-PAS sampling
#
# Missing meteorological observations are NOT imputed.


# Calculations (functions) ------------------------------------------------

PUF_PAS_Effective_Volume_Calculations <- function(
    start_date,
    end_date,
    met_data_path,
    pcb_properties_path,
    pcb_ppLFER_path,
    file_path) {
  
  
  # ----------------------------------------------------------------------
  # Specify the method for determining KPUF (1 or 2)
  # ----------------------------------------------------------------------
  
  KPUFMethod <- 1
  
  
  # ----------------------------------------------------------------------
  # Known variables about PUF disk parameters
  # ----------------------------------------------------------------------
  
  diameter <- 0.14
  thickness <- 0.0135
  dpuf <- 21173
  As <- 0.0365
  
  
  # Calculate PUF parameters based on inputs
  VPUF <- pi * ((diameter^2) / 4) * thickness
  
  
  # ----------------------------------------------------------------------
  # Read in site-specific meteorological data
  # ----------------------------------------------------------------------
  
  Met_Data <- read.csv(
    met_data_path,
    header = TRUE
  )
  
  
  # ----------------------------------------------------------------------
  # Import PCB properties
  # ----------------------------------------------------------------------
  
  PCB_Properties <- read.csv(
    pcb_properties_path,
    header = TRUE
  )
  
  PCB_ppLFER <- read.csv(
    pcb_ppLFER_path,
    header = TRUE
  )
  
  
  # ----------------------------------------------------------------------
  # Convert date column to POSIXct
  # ----------------------------------------------------------------------
  
  Met_Data$date <- as.POSIXct(
    Met_Data$date,
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  
  
  # ----------------------------------------------------------------------
  # Find closest start and end times
  # ----------------------------------------------------------------------
  
  StartTime <- which.min(
    abs(
      Met_Data$date -
        as.POSIXct(start_date, tz = "UTC")
    )
  )
  
  
  EndTime <- which.min(
    abs(
      Met_Data$date -
        as.POSIXct(end_date, tz = "UTC")
    )
  )
  
  
  # ----------------------------------------------------------------------
  # Check selected times
  # ----------------------------------------------------------------------
  
  if (EndTime < StartTime) {
    stop("The selected end date occurs before the selected start date.")
  }
  
  
  # Length of deployment (number of time steps)
  Length <- EndTime - (StartTime - 1)
  
  
  # ----------------------------------------------------------------------
  # Read meteorological variables
  #
  # GHCNh output file:
  #
  # Column 1 = date
  # Column 2 = TA   (Kelvin)
  # Column 3 = Pr   (Pascals)
  # Column 4 = WS   (m/s)
  # Column 5 = WD   (degrees)
  # Column 6 = QV
  # ----------------------------------------------------------------------
  
  T <- as.numeric(
    Met_Data[StartTime:EndTime, 2]
  )
  
  P <- as.numeric(
    Met_Data[StartTime:EndTime, 3]
  )
  
  WS <- as.numeric(
    Met_Data[StartTime:EndTime, 4]
  )
  
  Qvap <- as.numeric(
    Met_Data[StartTime:EndTime, 6]
  )
  
  
  # Prepare deployment-specific meteorological data
  DeploymentMetData <- Met_Data[
    StartTime:EndTime,
    ,
    drop = FALSE
  ]
  
  
  # ----------------------------------------------------------------------
  # Internal flowrate and wind speed exceedance calculation
  # ----------------------------------------------------------------------
  
  InternalFlowrate <- function(WS) {
    
    # Missing WS remains NA
    Vi <- rep(
      NA_real_,
      length(WS)
    )
    
    valid_WS <- !is.na(WS)
    
    
    # Wind speed <= 0.9 m/s
    Vi[
      valid_WS &
        WS <= 0.9
    ] <- 0
    
    
    # Wind speed > 0.9 m/s
    Vi[
      valid_WS &
        WS > 0.9
    ] <-
      0.3620 *
      WS[
        valid_WS &
          WS > 0.9
      ] -
      0.313
    
    
    # Wind-speed exceedance
    # calculated only using valid wind observations
    
    if (sum(valid_WS) > 0) {
      
      WScount <- sum(
        WS[valid_WS] > 5
      )
      
      WS_Exceedence <-
        WScount /
        sum(valid_WS) *
        100
      
    } else {
      
      WS_Exceedence <- NA_real_
    }
    
    
    return(
      list(
        Vi = Vi,
        WS_Exceedence = WS_Exceedence
      )
    )
  }
  
  
  result <- InternalFlowrate(WS)
  
  Vi <- result$Vi
  WS_Exceedence <- result$WS_Exceedence
  
  
  # ----------------------------------------------------------------------
  # Calculate average values for ViGamma and TGamma
  # ----------------------------------------------------------------------
  
  ViGamma <- mean(
    Vi,
    na.rm = TRUE
  )
  
  TGamma <- mean(
    T,
    na.rm = TRUE
  )
  
  
  # ----------------------------------------------------------------------
  # Diagnostic information
  # ----------------------------------------------------------------------
  
  cat("\n")
  cat("============================================================\n")
  cat("PUF-PAS MODEL DIAGNOSTIC\n")
  cat("============================================================\n")
  
  cat(
    "Length of deployment = ",
    Length,
    " hours\n",
    sep = ""
  )
  
  cat(
    "Valid temperature = ",
    sum(is.finite(T)),
    " of ",
    length(T),
    "\n",
    sep = ""
  )
  
  cat(
    "Valid pressure = ",
    sum(is.finite(P)),
    " of ",
    length(P),
    "\n",
    sep = ""
  )
  
  cat(
    "Valid wind speed = ",
    sum(is.finite(WS)),
    " of ",
    length(WS),
    "\n",
    sep = ""
  )
  
  cat(
    "Valid QV = ",
    sum(is.finite(Qvap)),
    " of ",
    length(Qvap),
    "\n",
    sep = ""
  )
  
  cat(
    "Valid internal flowrate = ",
    sum(is.finite(Vi)),
    " of ",
    length(Vi),
    "\n",
    sep = ""
  )
  
  cat(
    "ViGamma = ",
    ViGamma,
    "\n",
    sep = ""
  )
  
  cat(
    "TGamma = ",
    TGamma,
    "\n",
    sep = ""
  )
  
  cat(
    "Wind speed exceedance (>5 m/s) = ",
    WS_Exceedence,
    "%\n",
    sep = ""
  )
  
  
  # ----------------------------------------------------------------------
  # Identify missing meteorological hours
  # ----------------------------------------------------------------------
  
  MissingMet <- data.frame(
    date = DeploymentMetData$date,
    TA = T,
    Pr = P,
    WS = WS,
    QV = Qvap
  )
  
  
  MissingMet <- MissingMet[
    is.na(MissingMet$TA) |
      is.na(MissingMet$Pr) |
      is.na(MissingMet$WS) |
      is.na(MissingMet$QV),
    ,
    drop = FALSE
  ]
  
  
  cat("\n")
  cat("------------------------------------------------------------\n")
  cat("Missing meteorological observations\n")
  cat("------------------------------------------------------------\n")
  
  cat(
    "Number of hours with missing meteorological data = ",
    nrow(MissingMet),
    "\n",
    sep = ""
  )
  
  
  if (nrow(MissingMet) > 0) {
    print(MissingMet)
  }
  
  
  # ----------------------------------------------------------------------
  # Function to calculate GammaPCB
  # ----------------------------------------------------------------------
  
  GammaPCBCalculation <- function(
    ViGamma,
    TGamma,
    LKOA,
    LKOA28) {
    
    Gamma28 <-
      -0.153 +
      0.077 * ViGamma +
      0.000668 * TGamma -
      0.000310 * ViGamma * TGamma
    
    GammaPCB <-
      Gamma28 *
      (LKOA / LKOA28)
    
    return(GammaPCB)
  }
  
  
  # ----------------------------------------------------------------------
  # Function to calculate PCB diffusivity
  # ----------------------------------------------------------------------
  
  PCBDiffusivity <- function(T, P, mm) {
    
    VH2O <- 9.5
    VAir <- 20.1
    mH2O <- 18.015
    mAir <- 28.97
    
    D <-
      (
        (
          10^-3 *
            T^1.75 *
            (
              (1 / mAir) +
                (1 / mH2O)
            )^0.5
        ) /
          (
            P *
              (1 / 101325) *
              (
                VAir^(1 / 3) +
                  VH2O^(1 / 3)
              )^2
          )
      ) *
      (
        (mm / mH2O)^-0.5
      ) /
      100^2
    
    return(D)
  }
  
  
  # ----------------------------------------------------------------------
  # Function to calculate kinematic viscosity (m2/s)
  # ----------------------------------------------------------------------
  
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
    
    MuAir <-
      (
        17.78 *
          (
            4.58 *
              (T / Tca) -
              1.67
          )^0.625 *
          10^-7
      ) /
      Za
    
    MuWater <-
      (
        (
          7.55 *
            (T / Tcw) -
            0.55
        ) *
          (
            Zcw^-1.25
          ) *
          10^-7
      ) /
      Zw
    
    a <- ifelse(
      T >= 293.15,
      2.5,
      3.5
    )
    
    Mw <-
      Qvap *
      (1 / mH2O) *
      1000 *
      (
        P /
          (Rd * T)
      )
    
    Ma <-
      (1 / Qvap) *
      (1 / mAir) *
      1000 *
      1000
    
    Xw <-
      Mw /
      (Mw + Ma)
    
    Xa <-
      Ma /
      (Mw + Ma)
    
    DynamicMu <-
      (
        Xa * MuAir +
          Xw * MuWater
      ) *
      (
        1 +
          (
            (Xw - Xw^2) / a
          )
      )
    
    Pv <-
      Xw * P
    
    Pd <-
      Xa * P
    
    Density <-
      (
        Pd /
          (Rd * T)
      ) +
      (
        Pv /
          (Rv * T)
      )
    
    Kinematic <-
      DynamicMu /
      Density
    
    return(Kinematic)
  }
  
  
  # ----------------------------------------------------------------------
  # Function to calculate mass transfer rate
  # ----------------------------------------------------------------------
  
  MassTransfer <- function(
    Vi,
    Kinematic,
    GammaPCB,
    D,
    diameter) {
    
    Beta <- 1 / 3
    
    alpha <- ifelse(
      Vi < 0.5,
      0.5,
      0.9
    )
    
    Nu <-
      Kinematic^(
        Beta - alpha
      )
    
    kv <-
      GammaPCB *
      (
        D^(1 - Beta)
      ) *
      (
        Vi^alpha
      ) *
      Nu *
      (
        diameter^(alpha - 1)
      )
    
    return(kv)
  }
  
  
  # ----------------------------------------------------------------------
  # Function to calculate KPUF
  # ----------------------------------------------------------------------
  
  KPUFCalculation <- function(
    LKOA,
    dU,
    T,
    method,
    Congener_ppLFER) {
    
    if (method == 1) {
      
      Rg <- 8.3144
      
      # Adjust LKOA by temperature
      LKOAi <-
        LKOA -
        (
          dU /
            (2.303 * Rg)
        ) *
        (
          (1 / T) -
            (1 / 298.15)
        )
      
      # Calculate PUF/Air equilibrium partition coefficient
      KPUF <-
        10^(
          0.6366 *
            LKOAi -
            3.1774
        )
      
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
      
      E <- Congener_ppLFER[2]
      S <- Congener_ppLFER[3]
      A <- Congener_ppLFER[4]
      B <- Congener_ppLFER[5]
      L <- Congener_ppLFER[7]
      
      # Calculate logKPUF using the Abraham model
      logKPUF <-
        (
          cs -
            (ch / T)
        ) +
        (
          es -
            (eh / T)
        ) * E +
        (
          ss -
            (sh / T)
        ) * S +
        (
          as -
            (ah / T)
        ) * A +
        (
          bs -
            (bh / T)
        ) * B +
        (
          ls -
            (lh / T)
        ) * L
      
      # Calculate KPUF (m3/g)
      KPUF <-
        10^logKPUF /
        1000000
    }
    
    return(KPUF)
  }
  
  
  # ----------------------------------------------------------------------
  # Create array for deployment length and all PCBs
  # ----------------------------------------------------------------------
  
  numPCB <- nrow(
    PCB_Properties
  )
  
  
  PAS_Array <- array(
    NA_real_,
    dim = c(
      Length,
      numPCB,
      5
    )
  )
  
  
  # ----------------------------------------------------------------------
  # Main PCB calculation
  # ----------------------------------------------------------------------
  
  for (C in 1:numPCB) {
    
    # PCB-specific properties
    mm <- PCB_Properties[C, 2]
    dU <- PCB_Properties[C, 3]
    LKOA <- PCB_Properties[C, 4]
    Congener_ppLFER <- PCB_ppLFER[C, ]
    
    
    # GammaPCB
    GammaPCB <-
      GammaPCBCalculation(
        ViGamma,
        TGamma,
        LKOA,
        PCB_Properties[28, 4]
      )
    
    
    # --------------------------------------------------------------
    # Cumulative effective volume for this PCB
    # --------------------------------------------------------------
    
    cumulative_Veff <- 0
    
    
    # --------------------------------------------------------------
    # Hourly calculation
    # --------------------------------------------------------------
    
    for (t in 1:Length) {
      
      
      # ------------------------------------------------------------
      # Check whether required meteorological data exist
      # ------------------------------------------------------------
      
      MissingThisHour <-
        is.na(T[t]) ||
        is.na(P[t]) ||
        is.na(WS[t]) ||
        is.na(Qvap[t]) ||
        is.na(Vi[t])
      
      
      # ------------------------------------------------------------
      # Missing meteorological observation
      # ------------------------------------------------------------
      
      if (MissingThisHour) {
        
        # Keep calculated hourly values as NA.
        
        PAS_Array[t, C, 1] <- NA_real_
        PAS_Array[t, C, 2] <- NA_real_
        PAS_Array[t, C, 3] <- NA_real_
        PAS_Array[t, C, 4] <- NA_real_
        
        # Cumulative Veff remains unchanged.
        
        PAS_Array[t, C, 5] <- cumulative_Veff
        
        next
      }
      
      
      # ------------------------------------------------------------
      # Calculate PCB diffusivity
      # ------------------------------------------------------------
      
      D <- PCBDiffusivity(
        T[t],
        P[t],
        mm
      )
      
      
      # ------------------------------------------------------------
      # Calculate kinematic viscosity
      # ------------------------------------------------------------
      
      Kinematic <- Viscosity(
        T[t],
        Qvap[t],
        P[t]
      )
      
      
      # ------------------------------------------------------------
      # Calculate mass-transfer rate
      # ------------------------------------------------------------
      
      kv <- MassTransfer(
        Vi[t],
        Kinematic,
        GammaPCB,
        D,
        diameter
      )
      
      
      # ------------------------------------------------------------
      # Calculate sampling rate
      # ------------------------------------------------------------
      
      Rs <- kv *
        As *
        86400
      
      
      # ------------------------------------------------------------
      # Calculate KPUF
      # ------------------------------------------------------------
      
      KPUF <-
        KPUFCalculation(
          LKOA,
          dU,
          T[t],
          KPUFMethod,
          Congener_ppLFER
        ) *
        dpuf
      
      
      # ------------------------------------------------------------
      # Check calculated values
      # ------------------------------------------------------------
      
      if (
        !is.finite(D) ||
        !is.finite(Kinematic) ||
        !is.finite(kv) ||
        !is.finite(KPUF)
      ) {
        
        cat(
          "Invalid calculation at ",
          format(
            DeploymentMetData$date[t],
            "%Y-%m-%d %H:%M:%S"
          ),
          " | PCB = ",
          C,
          "\n",
          sep = ""
        )
        
        PAS_Array[t, C, 1] <- NA_real_
        PAS_Array[t, C, 2] <- NA_real_
        PAS_Array[t, C, 3] <- NA_real_
        PAS_Array[t, C, 4] <- NA_real_
        
        PAS_Array[t, C, 5] <- cumulative_Veff
        
        next
      }
      
      
      # ------------------------------------------------------------
      # Calculate effective volume
      # ------------------------------------------------------------
      
      if (t == 1) {
        
        Veff <-
          (
            kv * 3600
          ) *
          As /
          VPUF *
          (
            VPUF -
              (
                0 / KPUF
              )
          )
        
      } else {
        
        Veff <-
          (
            kv * 3600
          ) *
          As /
          VPUF *
          (
            VPUF -
              (
                cumulative_Veff /
                  KPUF
              )
          )
      }
      
      
      # ------------------------------------------------------------
      # Store hourly results
      # ------------------------------------------------------------
      
      PAS_Array[t, C, 1] <- Rs
      PAS_Array[t, C, 2] <- kv
      PAS_Array[t, C, 3] <- KPUF
      PAS_Array[t, C, 4] <- Veff
      
      
      # ------------------------------------------------------------
      # Update cumulative effective volume
      # ------------------------------------------------------------
      
      cumulative_Veff <-
        cumulative_Veff +
        Veff
      
      PAS_Array[t, C, 5] <-
        cumulative_Veff
      
    }
  }
  
  
  # ----------------------------------------------------------------------
  # Create matrix of final variables for each congener
  # ----------------------------------------------------------------------
  
  PAS_Final <- matrix(
    NA_real_,
    nrow = 2,
    ncol = numPCB
  )
  
  
  for (C in 1:numPCB) {
    
    # Average sampling rate over valid hours
    Rs_valid <- PAS_Array[
      ,
      C,
      1
    ]
    
    Rs_valid <- Rs_valid[
      is.finite(Rs_valid)
    ]
    
    
    if (length(Rs_valid) > 0) {
      
      RsAVG <- mean(
        Rs_valid
      )
      
    } else {
      
      RsAVG <- NA_real_
    }
    
    
    # Final cumulative effective volume
    Veff_valid <- PAS_Array[
      ,
      C,
      5
    ]
    
    Veff_valid <- Veff_valid[
      is.finite(Veff_valid)
    ]
    
    
    if (length(Veff_valid) > 0) {
      
      Veff_Final <-
        tail(
          Veff_valid,
          1
        )
      
    } else {
      
      Veff_Final <- NA_real_
    }
    
    
    PAS_Final[1, C] <- Veff_Final
    PAS_Final[2, C] <- RsAVG
  }
  
  
  # ----------------------------------------------------------------------
  # Format dates
  # ----------------------------------------------------------------------
  
  formatted_start_date <-
    format(
      as.POSIXct(start_date, tz = "UTC"),
      "%Y%m%d%H"
    )
  
  formatted_end_date <-
    format(
      as.POSIXct(end_date, tz = "UTC"),
      "%Y%m%d%H"
    )
  
  
  # ----------------------------------------------------------------------
  # Create row IDs
  # ----------------------------------------------------------------------
  
  rowID <- matrix(
    nrow = 2,
    ncol = 6
  )
  
  
  rowID[1, ] <- c(
    "1",
    formatted_start_date,
    formatted_end_date,
    as.character(Length),
    as.character(WS_Exceedence),
    "Veff"
  )
  
  
  rowID[2, ] <- c(
    "1",
    formatted_start_date,
    formatted_end_date,
    as.character(Length),
    as.character(WS_Exceedence),
    "SR"
  )
  
  
  # ----------------------------------------------------------------------
  # Combine results
  # ----------------------------------------------------------------------
  
  outData <- cbind(
    rowID,
    PAS_Final
  )
  
  
  # ----------------------------------------------------------------------
  # Column names
  # ----------------------------------------------------------------------
  
  column_names <- c(
    "PUF_ID",
    "Deployment",
    "Collection",
    "Length",
    "WS_Exceedence",
    "Type",
    PCB_Properties$Congener.s..ID
  )
  
  
  colnames(outData) <- column_names
  
  
  # ----------------------------------------------------------------------
  # Create output directory
  # ----------------------------------------------------------------------
  
  dir.create(
    dirname(file_path),
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  
  # ----------------------------------------------------------------------
  # Save results
  # ----------------------------------------------------------------------
  
  write.csv(
    outData,
    file = file_path,
    row.names = FALSE
  )
  
  
  # ----------------------------------------------------------------------
  # Final summary
  # ----------------------------------------------------------------------
  
  cat("\n")
  cat("============================================================\n")
  cat("PUF-PAS CALCULATION COMPLETE\n")
  cat("============================================================\n")
  
  cat(
    "Deployment: ",
    format(
      ActualStartDate,
      "%Y-%m-%d %H:%M"
    ),
    " to ",
    format(
      ActualEndDate,
      "%Y-%m-%d %H:%M"
    ),
    " UTC\n",
    sep = ""
  )
  
  cat(
    "Total hourly time steps: ",
    Length,
    "\n",
    sep = ""
  )
  
  cat(
    "Missing meteorological hours: ",
    nrow(MissingMet),
    "\n",
    sep = ""
  )
  
  cat(
    "Wind speed > 5 m/s: ",
    sprintf(
      "%.2f",
      WS_Exceedence
    ),
    "% of valid WS observations\n",
    sep = ""
  )
  
  cat(
    "Output saved to:\n",
    file_path,
    "\n"
  )
  
  
  return(outData)
}


# =========================================================================
# RUN THE MODEL
# =========================================================================

PUF_PAS_Effective_Volume_Calculations(
  
  start_date = "2026-03-01 01:00:00",
  
  end_date = "2026-04-10 01:00:00",
  
  # NOAA GHCNh meteorological data
  met_data_path =
    "Output/Data/GHCNh/USW00014819/USW00014819-2026-2026-GHCNh.csv",
  
  # PCB properties
  pcb_properties_path =
    "Data/PCB_Properties_MW_DU_KOA.csv",
  
  # PCB ppLFER descriptors
  pcb_ppLFER_path =
    "Data/PCB_LFER_descriptors.csv",
  
  # Final results
  file_path =
    "Output/Data/Results/GHCNh/VefChicagoMidwayAirport2026.csv"
)