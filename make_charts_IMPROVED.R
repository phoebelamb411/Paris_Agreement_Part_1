# ============================================================================
# Paris Agreement Part 1: Emissions vs Targets (2015-2024)
# ============================================================================
# 
# WHAT THIS SCRIPT DOES:
# 1. Loads historical emissions data from Climate Watch
# 2. Loads country NDC targets from targets.csv
# 3. Calculates if countries are on track to meet their 2030 goals
# 4. Creates line charts for each country showing progress
# 5. Creates a summary bar chart comparing all countries
#
# AUTHOR: Phoebe Lamb
# GITHUB: github.com/phoebelamb411/Paris_Agreement_Part_1
# ============================================================================


# ---- STEP 1: Load Required Packages ----------------------------------------

# These are the packages we need for this analysis
required_packages <- c("tidyverse", "janitor", "here", "scales")

# Check if packages are installed, and give helpful error if not
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is missing. Install it with: install.packages('", pkg, "')")
  }
}

# Load the packages
library(tidyverse)  # Data manipulation and visualization
library(janitor)    # Clean column names
library(here)       # Safe file paths
library(scales)     # Nice axis labels

cat("\n✓ All packages loaded successfully!\n\n")


# ---- STEP 2: Set Up Colors and Themes --------------------------------------

# Define our color scheme (consistent with Part 2)
COL_ON_TRACK   <- "#2E7D32"  # Green for on-track countries
COL_OFF_TRACK  <- "#C62828"  # Red for off-track countries
COL_LINE_MAIN  <- "#111111"  # Dark color for main line
COL_GREY       <- "#6B7280"  # Grey for secondary elements

# Country flags for visual appeal
COUNTRY_FLAGS <- c(
  USA  = "🇺🇸",
  GBR  = "🇬🇧",
  EU27 = "🇪🇺",
  JPN  = "🇯🇵",
  CAN  = "🇨🇦"
)

# Custom ggplot theme for clean, professional charts
theme_clean <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold", size = base_size + 4),
      plot.subtitle = element_text(color = COL_GREY, size = base_size),
      plot.caption  = element_text(color = COL_GREY, size = base_size - 2, hjust = 0),
      axis.title    = element_text(color = "#111"),
      axis.text     = element_text(color = "#111"),
      panel.grid.minor = element_blank()
    )
}

# Standard caption for all charts
CHART_CAPTION <- "Analysis: Phoebe Lamb | Data: Climate Watch (WRI) + UNFCCC NDC Registry"


# ---- STEP 3: Set Up File Paths and Options ---------------------------------

# Make sure we're in the project directory
if (!dir.exists(here())) {
  stop("Can't find project root. Open the .Rproj file first!")
}

# Define folder paths
DATA_FOLDER    <- here("raw_data")
OUTPUT_FOLDER  <- here("output", "figures")
COUNTRY_FOLDER <- here("output", "figures", "country_lines")

# Create output folders if they don't exist
dir.create(COUNTRY_FOLDER, recursive = TRUE, showWarnings = FALSE)

# Countries to analyze (easy to add more later!)
COUNTRIES_TO_ANALYZE <- c("USA", "GBR", "EU27", "JPN", "CAN")

# Should we smooth the 2015 baseline? (helps with COVID weirdness)
USE_SMOOTHED_BASELINE <- TRUE

cat("✓ Project setup complete!\n")
cat("  Data folder:", DATA_FOLDER, "\n")
cat("  Output folder:", OUTPUT_FOLDER, "\n\n")


# ---- STEP 4: Load Emissions Data -------------------------------------------

cat("Loading emissions data from Climate Watch...\n")

# Find the Climate Watch emissions file
emissions_file <- here("raw_data", "CW_HistoricalEmissions_ClimateWatch.csv")

if (!file.exists(emissions_file)) {
  # Try to find it with a different name
  possible_files <- list.files(
    DATA_FOLDER, 
    pattern = "ClimateWatch.*\\.csv$", 
    full.names = TRUE
  )
  
  if (length(possible_files) == 0) {
    stop("Can't find Climate Watch emissions file in raw_data/\n",
         "Download from: https://www.climatewatchdata.org/ghg-emissions")
  }
  
  emissions_file <- possible_files[1]
}

cat("  Using file:", basename(emissions_file), "\n")

# Read the CSV and clean column names
raw_data <- read_csv(emissions_file, show_col_types = FALSE) %>%
  clean_names()  # Converts "1990" to "x1990", etc.

# Find year columns (they look like x1990, x1991, x2022, etc.)
year_columns <- grep("^x?(19|20)[0-9]{2}$", names(raw_data), value = TRUE)

if (length(year_columns) == 0) {
  stop("Can't find year columns. Expected names like 'x1990', 'x2022', etc.")
}

cat("  Found", length(year_columns), "years of data\n")

# Reshape from wide to long format
# BEFORE: iso3 | x1990 | x1991 | x1992 ...
# AFTER:  iso3 | year  | value
emissions_long <- raw_data %>%
  pivot_longer(
    cols = all_of(year_columns),
    names_to = "year",
    values_to = "emissions_mtco2e"
  ) %>%
  mutate(
    year = as.integer(gsub("^x", "", year))  # Remove 'x' prefix
  )

# Filter for the data we want:
# - Sector: "Total excluding LULUCF" (land use change)
# - Gas: "All GHG" (all greenhouse gases)
emissions_filtered <- emissions_long %>%
  filter(
    grepl("total.*excl.*lulucf", sector, ignore.case = TRUE),
    grepl("all|ghg|kyoto", gas, ignore.case = TRUE)
  )

# Which column has country codes?
country_column <- names(emissions_filtered)[grepl("country|iso", names(emissions_filtered), ignore.case = TRUE)][1]

# Check if we have ISO3 codes (like USA, GBR) or full names
sample_values <- toupper(emissions_filtered[[country_column]])
has_iso_codes <- mean(grepl("^[A-Z]{3}$", sample_values)) >= 0.9

if (has_iso_codes) {
  # Already have ISO3 codes - just standardize
  emissions_clean <- emissions_filtered %>%
    mutate(
      iso3 = toupper(.data[[country_column]]),
      # Normalize EU variants
      iso3 = case_when(
        iso3 %in% c("EUU", "EU27", "EU28", "E27", "EUR") ~ "EU27",
        TRUE ~ iso3
      )
    ) %>%
    select(iso3, year, emissions_mtco2e)
  
} else {
  # Need to map country names to ISO3 codes
  cat("  Mapping country names to ISO3 codes...\n")
  
  emissions_clean <- emissions_filtered %>%
    mutate(
      country_upper = toupper(trimws(.data[[country_column]])),
      iso3 = case_when(
        grepl("UNITED STATES", country_upper) ~ "USA",
        grepl("UNITED KINGDOM|GREAT BRITAIN", country_upper) ~ "GBR",
        grepl("EUROPEAN UNION", country_upper) ~ "EU27",
        grepl("^JAPAN$", country_upper) ~ "JPN",
        grepl("^CANADA$", country_upper) ~ "CAN",
        TRUE ~ NA_character_
      )
    ) %>%
    filter(!is.na(iso3)) %>%
    select(iso3, year, emissions_mtco2e)
}

# Keep only our study countries and add pretty names
emissions_data <- emissions_clean %>%
  filter(iso3 %in% COUNTRIES_TO_ANALYZE) %>%
  mutate(
    country_name = case_when(
      iso3 == "USA"  ~ "United States",
      iso3 == "GBR"  ~ "United Kingdom",
      iso3 == "EU27" ~ "European Union (27)",
      iso3 == "JPN"  ~ "Japan",
      iso3 == "CAN"  ~ "Canada"
    )
  )

cat("✓ Emissions data loaded:", nrow(emissions_data), "observations\n")
cat("  Countries:", paste(unique(emissions_data$country_name), collapse = ", "), "\n\n")


# ---- STEP 5: Load Target Data ----------------------------------------------

cat("Loading NDC targets from targets.csv...\n")

targets_file <- here("raw_data", "targets.csv")

if (!file.exists(targets_file)) {
  stop("Can't find targets.csv in raw_data/\n",
       "This file should have columns: iso3, base_year, target_year, reduction_pct")
}

# Read targets
targets <- read_csv(targets_file, show_col_types = FALSE) %>%
  clean_names()

# Validate targets file
required_columns <- c("iso3", "base_year", "target_year", "reduction_pct")
missing_columns <- setdiff(required_columns, names(targets))

if (length(missing_columns) > 0) {
  stop("targets.csv is missing columns: ", paste(missing_columns, collapse = ", "))
}

cat("✓ Targets loaded for", nrow(targets), "countries\n\n")


# ---- STEP 6: Calculate 2015 Baseline (with optional smoothing) ------------

cat("Calculating 2015 baseline emissions...\n")

if (USE_SMOOTHED_BASELINE) {
  # Use 3-year average (2014-2016) to smooth out anomalies
  baseline_data <- emissions_data %>%
    filter(year >= 2014, year <= 2016) %>%
    group_by(iso3, country_name) %>%
    summarize(
      baseline_2015 = mean(emissions_mtco2e, na.rm = TRUE),
      .groups = "drop"
    )
  cat("  Using 3-year average (2014-2016) for baseline\n")
  
} else {
  # Use exact 2015 value
  baseline_data <- emissions_data %>%
    filter(year == 2015) %>%
    select(iso3, country_name, baseline_2015 = emissions_mtco2e)
  cat("  Using exact 2015 value for baseline\n")
}

cat("✓ Baselines calculated\n\n")


# ---- STEP 7: Helper Functions ----------------------------------------------

# Function to calculate compound annual growth rate (CAGR)
# Negative values = decline (which is good for emissions!)
calculate_cagr <- function(start_value, end_value, years) {
  if (is.na(start_value) || is.na(end_value) || years <= 0) {
    return(NA_real_)
  }
  ((end_value / start_value) ^ (1 / years)) - 1
}

# Function to format percentages nicely
format_percent <- function(x, decimals = 0.1) {
  if (is.na(x)) return("N/A")
  pct <- x * 100
  if (abs(pct) < decimals) return("≈0%")
  sprintf("%+.1f%%", pct)
}


# ---- STEP 8: Analyze Each Country ------------------------------------------

cat("Analyzing each country...\n\n")
cat("="*70, "\n\n", sep = "")

# Store results for all countries
all_results <- list()

# Loop through each country
for (country_code in COUNTRIES_TO_ANALYZE) {
  
  cat("Analyzing:", country_code, "\n")
  
  # Get this country's emissions data
  country_emissions <- emissions_data %>%
    filter(iso3 == country_code) %>%
    arrange(year)
  
  if (nrow(country_emissions) == 0) {
    warning("No emissions data for ", country_code, ". Skipping.")
    next
  }
  
  # Get this country's target
  country_target <- targets %>%
    filter(iso3 == country_code)
  
  if (nrow(country_target) == 0) {
    warning("No target data for ", country_code, ". Skipping.")
    next
  }
  
  # Get baseline and latest emissions
  baseline <- baseline_data %>%
    filter(iso3 == country_code) %>%
    pull(baseline_2015)
  
  latest_year <- max(country_emissions$year)
  latest_emissions <- country_emissions %>%
    filter(year == latest_year) %>%
    pull(emissions_mtco2e)
  
  # Calculate 2030 target value
  base_year_emissions <- country_emissions %>%
    filter(year == country_target$base_year) %>%
    pull(emissions_mtco2e)
  
  if (length(base_year_emissions) == 0) {
    warning("Missing base year (", country_target$base_year, ") for ", country_code)
    next
  }
  
  target_2030 <- base_year_emissions * (1 - country_target$reduction_pct / 100)
  
  # Calculate rates of change
  years_since_2015 <- latest_year - 2015
  observed_rate <- calculate_cagr(baseline, latest_emissions, years_since_2015)
  required_rate <- calculate_cagr(baseline, target_2030, 2030 - 2015)
  
  # Project where we'll be in 2030 if current trend continues
  projected_2030 <- baseline * (1 + observed_rate) ^ (2030 - 2015)
  
  # Determine if on track (observed decline >= required decline)
  is_on_track <- !is.na(observed_rate) && !is.na(required_rate) && observed_rate <= required_rate
  
  # Calculate how far off we are
  gap_2030 <- projected_2030 - target_2030
  
  # Store results
  all_results[[country_code]] <- tibble(
    iso3 = country_code,
    country = country_emissions$country_name[1],
    baseline_2015 = baseline,
    latest_year = latest_year,
    latest_emissions = latest_emissions,
    target_2030 = target_2030,
    observed_rate = observed_rate,
    required_rate = required_rate,
    projected_2030 = projected_2030,
    gap_2030 = gap_2030,
    on_track = is_on_track
  )
  
  # Print summary
  cat("  Baseline (2015):", comma(round(baseline)), "Mt CO2e\n")
  cat("  Latest (", latest_year, "): ", comma(round(latest_emissions)), " Mt CO2e\n", sep = "")
  cat("  2030 Target:", comma(round(target_2030)), "Mt CO2e\n")
  cat("  Observed rate:", format_percent(observed_rate), "per year\n")
  cat("  Required rate:", format_percent(required_rate), "per year\n")
  cat("  Status:", if(is_on_track) "✓ ON TRACK" else "✗ OFF TRACK", "\n")
  cat("  Gap:", comma(round(gap_2030)), "Mt CO2e", 
      if(gap_2030 < 0) "(better than target)" else "(worse than target)", "\n")
  
  
  # ---- Create Line Chart for This Country ----
  
  status_label <- if(is_on_track) "On Track" else "Off Track"
  status_color <- if(is_on_track) COL_ON_TRACK else COL_OFF_TRACK
  
  subtitle_text <- paste0(
    "Observed: ", format_percent(observed_rate), "/yr  |  ",
    "Required: ", format_percent(required_rate), "/yr"
  )
  
  chart <- ggplot(country_emissions, aes(x = year, y = emissions_mtco2e)) +
    # Historical emissions line
    geom_line(linewidth = 1.2, color = COL_LINE_MAIN) +
    
    # Path from 2015 baseline to 2030 target (dashed)
    annotate(
      "segment",
      x = 2015, xend = 2030,
      y = baseline, yend = target_2030,
      linetype = "dashed",
      linewidth = 0.9,
      color = COL_GREY
    ) +
    
    # 2030 target point
    annotate(
      "point",
      x = 2030,
      y = target_2030,
      size = 5,
      shape = 21,
      fill = status_color,
      color = "black",
      stroke = 1.2
    ) +
    
    # Flag watermark
    annotate(
      "text",
      x = min(country_emissions$year) + 1,
      y = max(country_emissions$emissions_mtco2e) * 0.95,
      label = COUNTRY_FLAGS[country_code],
      size = 12,
      alpha = 0.25,
      hjust = 0,
      vjust = 1
    ) +
    
    # Scales and labels
    scale_x_continuous(breaks = pretty_breaks(8)) +
    scale_y_continuous(
      labels = comma,
      expand = expansion(mult = c(0.02, 0.10))
    ) +
    labs(
      title = paste0(country_emissions$country_name[1], " — Emissions vs 2030 Target"),
      subtitle = subtitle_text,
      x = "Year",
      y = "Mt CO₂e (All GHG)",
      caption = CHART_CAPTION
    ) +
    coord_cartesian(clip = "off") +
    theme_clean(14)
  
  # Save chart
  output_file <- here("output", "figures", "country_lines", paste0(country_code, "_line.png"))
  ggsave(output_file, chart, width = 10, height = 6, dpi = 300, bg = "white")
  
  cat("  ✓ Chart saved:", basename(output_file), "\n\n")
}

cat("="*70, "\n\n", sep = "")


# ---- STEP 9: Create Summary Table ------------------------------------------

cat("Creating summary table...\n")

# Combine all results
summary_table <- bind_rows(all_results) %>%
  arrange(gap_2030) %>%  # Sort by gap (best to worst)
  mutate(
    on_track = as.logical(on_track),
    country_flag = paste(COUNTRY_FLAGS[iso3], country)
  )

# Save to CSV
output_csv <- here("output", "summary_ontrack.csv")
write_csv(summary_table, output_csv)

cat("✓ Summary table saved:", basename(output_csv), "\n")
cat("  Rows:", nrow(summary_table), "\n\n")


# ---- STEP 10: Create Summary Bar Chart -------------------------------------

cat("Creating summary bar chart...\n")

# Prepare data for plotting
plot_data <- summary_table %>%
  mutate(
    country_flag = factor(country_flag, levels = country_flag),  # Keep sorted order
    label_number = comma(round(gap_2030, 0)),
    label_status = case_when(
      gap_2030 <= 0      ~ "ahead of target",
      gap_2030 > 1000    ~ "far off track",
      gap_2030 > 300     ~ "needs big acceleration",
      TRUE               ~ "needs acceleration"
    )
  )

# Create bar chart
bar_chart <- ggplot(plot_data, aes(x = gap_2030, y = country_flag, fill = on_track)) +
  # Green shaded region for "better than target"
  annotate(
    "rect",
    xmin = -Inf, xmax = 0,
    ymin = -Inf, ymax = Inf,
    fill = alpha(COL_ON_TRACK, 0.06)
  ) +
  
  # Bars
  geom_col() +
  
  # Zero line
  geom_vline(xintercept = 0, linewidth = 0.6, color = COL_GREY) +
  
  # Numbers on bars
  geom_text(
    aes(
      label = label_number,
      hjust = ifelse(gap_2030 >= 0, -0.15, 1.15)
    ),
    size = 3.5,
    fontface = "bold"
  ) +
  
  # Status labels
  geom_text(
    aes(
      label = label_status,
      x = gap_2030 + ifelse(gap_2030 >= 0, max(gap_2030) * 0.10, -max(gap_2030) * 0.10),
      hjust = ifelse(gap_2030 >= 0, 0, 1)
    ),
    size = 3.8,
    color = COL_GREY
  ) +
  
  # Colors
  scale_fill_manual(
    values = c(`TRUE` = COL_ON_TRACK, `FALSE` = COL_OFF_TRACK),
    guide = "none"
  ) +
  
  # Axes
  scale_x_continuous(
    breaks = pretty_breaks(8),
    labels = comma,
    expand = expansion(mult = c(0.04, 0.40))
  ) +
  
  labs(
    title = "Projected 2030 Emissions vs Pledged Targets",
    subtitle = "Gap = Projected emissions at current pace minus 2030 target (negative = ahead of target)",
    x = "Mt CO₂e Gap",
    y = NULL,
    caption = CHART_CAPTION
  ) +
  
  coord_cartesian(clip = "off") +
  theme_clean(15) +
  theme(plot.title = element_text(face = "bold"))

# Save chart
output_bar <- here("output", "figures", "ontrack_bar.png")
ggsave(output_bar, bar_chart, width = 12, height = 7, dpi = 300, bg = "white")

cat("✓ Bar chart saved:", basename(output_bar), "\n\n")


# ---- STEP 11: Print Final Summary ------------------------------------------

cat("="*70, "\n", sep = "")
cat("✅ ANALYSIS COMPLETE!\n")
cat("="*70, "\n\n", sep = "")

cat("📊 Summary:\n")
cat("  Total countries analyzed:", nrow(summary_table), "\n")
cat("  On track:", sum(summary_table$on_track), "\n")
cat("  Off track:", sum(!summary_table$on_track), "\n\n")

cat("📁 Output files:\n")
cat("  Summary CSV:", output_csv, "\n")
cat("  Bar chart:", output_bar, "\n")
cat("  Country charts:", COUNTRY_FOLDER, "\n\n")

cat("🔍 Key Findings:\n")
for (i in seq_len(nrow(summary_table))) {
  row <- summary_table[i, ]
  status_icon <- if(row$on_track) "✓" else "✗"
  cat("  ", status_icon, " ", row$country, ": ",
      if(row$gap_2030 < 0) "ahead by" else "behind by", " ",
      comma(abs(round(row$gap_2030))), " Mt CO2e\n", sep = "")
}

cat("\n")
cat("="*70, "\n", sep = "")
cat("Next steps:\n")
cat("  1. Review charts in output/figures/\n")
cat("  2. Check summary_ontrack.csv for detailed numbers\n")
cat("  3. Share findings on LinkedIn!\n")
cat("="*70, "\n\n", sep = "")

# Save session info for reproducibility
session_file <- here("output", "session_info.txt")
capture.output(sessionInfo(), file = session_file)
cat("Session info saved to:", session_file, "\n\n")
