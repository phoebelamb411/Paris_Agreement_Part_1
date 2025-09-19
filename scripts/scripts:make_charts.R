getwd()
# scripts/make_charts.R
# (running this should create charts in output/figures/ and a summary CSV)

# loading the libraries I’ll need
library(tidyverse)
library(scales)

# I want to start with 5 countries so this stays bite-sized (can add more later)
COUNTRIES <- c("USA","GBR","EU27","JPN","CAN")

# I think smoothing 2015 with a 3-year avg helps with weird noise (covid, etc.)
USE_THREE_YEAR_AVG <- TRUE

# setting up folder paths so I don’t hardcode strings everywhere
RAW_DIR   <- "raw_data"
OUT_DIR   <- "output/figures"
OUT_LINES <- file.path(OUT_DIR, "country_lines")
dir.create(OUT_LINES, recursive = TRUE, showWarnings = FALSE)

# ---- step 1: find the right Climate Watch file automatically ----
# I downloaded a bunch of CSVs; I want to prefer the harmonized ClimateWatch one.
# if it's not there, I’ll fall back to UNFCCC/PRIMAP/GCP/US in that order.

candidate_files <- list.files(RAW_DIR, pattern = "^CW_HistoricalEmissions_.*\\.csv$", full.names = TRUE)
pick_first <- function(pattern) {
  match <- grep(pattern, candidate_files, value = TRUE, ignore.case = TRUE)
  if (length(match) > 0) match[1] else NA_character_
}

EMISS_PATH <- pick_first("ClimateWatch")
if (is.na(EMISS_PATH)) EMISS_PATH <- pick_first("UNFCCC")
if (is.na(EMISS_PATH)) EMISS_PATH <- pick_first("PRIMAP")
if (is.na(EMISS_PATH)) EMISS_PATH <- pick_first("GCP")
if (is.na(EMISS_PATH)) EMISS_PATH <- pick_first("US")

if (is.na(EMISS_PATH)) stop("hmm I can’t find any 'CW_HistoricalEmissions_*.csv' in data/raw/")
message("ok using this emissions file: ", basename(EMISS_PATH))

# ---- step 2 (clean & sturdy, patched 3x): get Total (excl LULUCF) + All GHG for my 5 countries ----
raw <- readr::read_csv(EMISS_PATH, show_col_types = FALSE)

# 1) Make sure I really have a country column and clean it
if (!"Country" %in% names(raw)) stop("I expected a 'Country' column in this file.")
raw <- raw %>% mutate(country_raw = trimws(Country))

# 2) Pivot the wide years (1990..2022) into tidy rows
year_cols <- grep("^[0-9]{4}$", names(raw), value = TRUE)
if (length(year_cols) == 0) stop("I expected year columns like 1990..2022 in this file")

long <- raw %>%
  tidyr::pivot_longer(all_of(year_cols), names_to = "year", values_to = "value_mtco2e") %>%
  mutate(year = as.integer(year))

# 3) Choose Sector = Total excluding LULUCF (fallback to including if needed)
sector_excl <- grepl("total", long$Sector, TRUE) & grepl("excl", long$Sector, TRUE) & grepl("lu?l?ucf", long$Sector, TRUE)
sector_incl <- grepl("total", long$Sector, TRUE) & grepl("incl", long$Sector, TRUE) & grepl("lu?l?ucf", long$Sector, TRUE)
sector_keep <- if (any(sector_excl, na.rm = TRUE)) sector_excl else {
  if (any(sector_incl, na.rm = TRUE)) {
    warning("Using 'Total including LULUCF' as a fallback.")
    sector_incl
  } else stop("No 'Total ... LULUCF' sector found.")
}

# 4) Keep All GHG / Kyoto / GHG
gas_keep <- grepl("all|kyoto|ghg", long$Gas, ignore.case = TRUE)

# 5) Filter to my 5 countries using flexible name matching, then map to ISO3

# sector_keep / gas_keep defined above
emis <- long %>%
  dplyr::filter(sector_keep & gas_keep) %>%
  dplyr::mutate(
    iso3 = dplyr::case_when(
      grepl("United\\s+States", country_raw, ignore.case = TRUE) ~ "USA",
      grepl("United\\s+States\\s+of\\s+America", country_raw, ignore.case = TRUE) ~ "USA",
      grepl("^United\\s+Kingdom", country_raw, ignore.case = TRUE) ~ "GBR",
      grepl("United\\s+Kingdom\\s+of\\s+Great\\s+Britain", country_raw, ignore.case = TRUE) ~ "GBR",
      grepl("^European\\s+Union", country_raw, ignore.case = TRUE) ~ "EU27",
      grepl("European\\s+Union\\s*\\(27\\)", country_raw, ignore.case = TRUE) ~ "EU27",
      grepl("^Japan$", country_raw, ignore.case = TRUE) ~ "JPN",
      grepl("^Canada$", country_raw, ignore.case = TRUE) ~ "CAN",
      TRUE ~ NA_character_
    )
  ) %>%
  dplyr::filter(!is.na(iso3) & iso3 %in% COUNTRIES) %>%
  dplyr::transmute(
    iso3,
    country = country_raw,
    year,
    value_mtco2e
  )

# sanity check
dim(emis); dplyr::count(emis, iso3); head(emis)


#confirming targets.csv is present
readr::read_csv("raw_data/targets.csv", show_col_types = FALSE)


# ---- step 3: load the tiny targets file I typed myself ----
TGT_PATH <- file.path(RAW_DIR, "targets.csv")
if (!file.exists(TGT_PATH)) stop("I need data/raw/targets.csv. I’ll paste the template from the instructions and fill it.")
TGT <- readr::read_csv(TGT_PATH, show_col_types = FALSE) %>% rename_with(tolower)

# helper: 3-year mean around 2015 baseline (less noisy)
three_year_mean <- function(series, center_year){
  yrs <- c(center_year-1, center_year, center_year+1)
  mean(series[as.character(yrs)], na.rm = TRUE)
}

# CAGR formula (how fast emissions are changing each year on average)
cagr <- function(e0, e1, yrs){
  if (is.na(e0) || is.na(e1) || e0 <= 0 || e1 <= 0 || yrs <= 0) return(NA_real_)
  (e1/e0)^(1/yrs) - 1
}

# ---- step 4: loop through countries, compute on-track test, and plot ----
results <- list()

for (cc in COUNTRIES) {
  ser <- emis %>% filter(iso3 == cc) %>% arrange(year)
  if (nrow(ser) == 0 || !(2015 %in% ser$year)) {
    message("skipping ", cc, " (no data or missing 2015)")
    next
  }
  s <- setNames(ser$value_mtco2e, ser$year)
  
  # baseline (2015). I’ll smooth if the toggle is TRUE.
  e2015 <- if (USE_THREE_YEAR_AVG) three_year_mean(s, 2015) else s["2015"]
  latest_year <- max(ser$year, na.rm = TRUE)
  e_latest <- s[as.character(latest_year)]
  
  # grab the target row for this country
  trow <- TGT %>% filter(toupper(iso3) == cc) %>% slice_head(n = 1)
  if (nrow(trow) == 0) { message("no target row for ", cc); next }
  
  # If I have an absolute target (excl. LULUCF), I’ll use it; otherwise compute from % below base year.
  if ("target_abs_excl_lulucf_mtco2e" %in% names(trow) && !is.na(trow$target_abs_excl_lulucf_mtco2e)) {
    e2030 <- as.numeric(trow$target_abs_excl_lulucf_mtco2e)
  } else {
    if (is.na(trow$base_year) || is.na(trow$reduction_pct)) {
      message(cc, ": I need either an absolute target OR a % + base_year. skipping for now.")
      next
    }
    base_val <- s[as.character(trow$base_year)]
    if (is.na(base_val)) { message(cc, ": base year not found in emissions data. skipping."); next }
    e2030 <- base_val * (1 - as.numeric(trow$reduction_pct)/100)
  }
  
  # observed vs required decline rates
  r_obs <- cagr(e2015, e_latest, latest_year - 2015)
  r_req <- cagr(e2015, e2030, 2030 - 2015)
  
  # if we keep going at the observed pace, where would 2030 land?
  proj2030 <- ifelse(is.na(r_obs), NA_real_, e2015 * (1 + r_obs)^(2030 - 2015))
  on_track <- (!is.na(r_obs) && !is.na(r_req) && r_obs <= r_req)
  
  results[[length(results)+1]] <- tibble(
    iso3 = cc,
    country = ser$country[1],
    latest_year = latest_year,
    E2015 = e2015,
    E_latest = e_latest,
    E2030_target = e2030,
    r_obs = r_obs,
    r_req = r_req,
    proj_2030 = proj2030,
    delta_2030 = proj2030 - e2030,
    on_track = on_track
  )
  
  # per-country line chart: actuals + dashed line down to 2030 target
  g <- ggplot(ser, aes(year, value_mtco2e)) +
    geom_line(linewidth = 1.2) +
    geom_segment(aes(x = 2015, xend = 2030, y = e2015, yend = e2030), linetype = "dashed") +
    geom_point(aes(x = 2030, y = e2030), size = 2.6) +
    labs(title = paste0(ser$country[1], ": Emissions since 2015 vs 2030 target"),
         x = "Year", y = "MtCO\u2082e (GHG, excl. LULUCF)") +
    theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank())
  
  ggsave(file.path(OUT_LINES, paste0(cc, "_line.png")), g, width = 9, height = 5, dpi = 220)
}

summary_df <- bind_rows(results) %>% arrange(delta_2030)
readr::write_csv(summary_df, "output/summary_ontrack.csv")

# on/off-track bar chart (negative delta_2030 = better than target)
bar <- ggplot(summary_df, aes(y = reorder(country, delta_2030), x = delta_2030, fill = on_track)) +
  geom_col() +
  geom_vline(xintercept = 0, linewidth = 0.6) +
  scale_fill_manual(values = c(`TRUE` = "#2E7D32", `FALSE` = "#C62828"), guide = "none") +
  geom_text(aes(label = comma(round(delta_2030, 0)),
                hjust = ifelse(delta_2030 >= 0, -0.1, 1.1)),
            size = 3) +
  labs(title = "Projected 2030 minus Target (negative = better than target)",
       x = "MtCO\u2082e", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"))

ggsave(file.path(OUT_DIR, "ontrack_bar.png"), bar, width = 10, height = 6.5, dpi = 220)

message("Done! Charts in output/figures/. Summary table at output/summary_ontrack.csv")
