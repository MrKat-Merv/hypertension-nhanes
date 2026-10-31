# 1. Important libraries
library(dplyr)    # the "verb" functions(filter(), mutate(), inner_join(), etc)
library(readr)    # a faster, more predictable replacement for base R's read.csv() - family functions 
library(foreign)  # the package that reads .XPT (SAS Transport) files, the format CDC publishes NHANES data in.

# 2. a reusable download function
# What this does?: We define a function so we do not repeat the same 
# download-and-read logic five times.
  
get_nhanes_file <- function(table_name, year_folder = "2017") {
  local_path <- file.path("data", "raw", paste0(table_name, ".xpt"))
  if (!file.exists(local_path)) {
    url <- paste0(
      "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/", year_folder,
      "/DataFiles/", table_name, ".xpt"
    )
    download.file(url, destfile = local_path, mode = "wb")
  }
  foreign::read.xport(local_path)
}

demo <- get_nhanes_file("DEMO_J")   # demographics
bpx <- get_nhanes_file("BPX_J")     # blood pressure exam
bmx <- get_nhanes_file("BMX_J")     # body measures (includes BMI)
smq <- get_nhanes_file("SMQ_J")     # smoking questionnaire
paq <- get_nhanes_file("PAQ_J")     # physical activity questionnaire

dim(demo); dim(bpx); dim(bmx); dim(smq); dim(paq)

writeLines(
  paste("NHANES 2017-2018 cycle. Downloaded:", Sys.Date()),
  "data/raw/SOURCE.txt"
)