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

# 3. Download all five tables

demo <- get_nhanes_file("DEMO_J")   # demographics
bpx <- get_nhanes_file("BPX_J")     # blood pressure exam
bmx <- get_nhanes_file("BMX_J")     # body measures (includes BMI)
smq <- get_nhanes_file("SMQ_J")     # smoking questionnaire
paq <- get_nhanes_file("PAQ_J")     # physical activity questionnaire

dim(demo); dim(bpx); dim(bmx); dim(smq); dim(paq)

# 4. Download the CDC's documentation pages for the same five tables.
# The .xpt files hold numbers, but column names like BPXSY2,
# SMQ040 or PAQ650 mean nothing on their own. For every data the CDC publishes 
# a matching documentation page ("Data Documentation, Codebook, and Frequencies")
# that explains every variable. We are downloading them too.

dir.create("docs/codebook", recursive = TRUE, showWarnings = FALSE)

get_codebook_page <- function(table_name, year_folder = "2017") {
  local_path <- file.path("docs", "codebook", paste0(table_name, ".htm"))
  if (!file.exists(local_path)) {
    url <- paste0(
      "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/", year_folder,
      "/DataFiles/", table_name, ".htm"
    )
    download.file(url, destfile = local_path, mode = "wb")
  }
  local_path
}

for (tbl in c("DEMO_J", "BPX_J", "BMX_J", "SMQ_J", "PAQ_J")) {
  get_codebook_page(tbl)
}

file.info(list.files("docs/codebook", full.names = TRUE))[, "size", drop = FALSE]

writeLines(
  paste("NHANES 2017-2018 cycle. Downloaded:", Sys.Date()),
  "data/raw/SOURCE.txt"
)

