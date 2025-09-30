# ------------------------------------------------------------
# Paris Agreement – Part 1 (2015–2024)
# Repo: https://github.com/phoebelamb411/Paris_Agreement_Part_1
#
# What I'm trying to do (in plain english):
# 1) Load Climate Watch emissions (ideally "Total excluding LULUCF")
# 2) Reshape to tidy format: iso3 / country / year / value
# 3) Load my small NDC targets file (targets.csv that I typed)
# 4) For each country: compare the trend since 2015 vs the 2030 target
# 5) Save: per-country line charts + one on/off-track bar chart
#
# Design choices I might forget later:
# - 2015 baseline = 3-year mean (2014–2016) to smooth weirdness (e.g. COVID)
# - "On track" = the observed decline is at least as fast as the required decline
# - LinkedIn images: portrait, fewer x-axis ticks so years don’t pile up
# ------------------------------------------------------------


# ---- 0) packages I need -----------------------------------------------------
# I'm using tidyverse for data/plots, janitor to clean column names,
# here for consistent file paths, scales for nice axis labels.
for (pkg in c("tidyverse","janitor","here","scales")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is not installed. Install it first: install.packages('", pkg, "')")
  }
}
library(tidyverse)
library(janitor)
library(here)
library(scales)


# ---- 1) colors/flags/themes I reuse -----------------------------------------
# my “brand” colors
COL_ON   <- "#2E7D32"  # green  (on-track)
COL_OFF  <- "#C62828"  # red    (off-track)
COL_LINE <- "#111111"  # dark ink for the time series
COL_GREY <- "#6B7280"  # soft grey for secondary lines/text

# cute flag watermarks for the 5 countries (I can add more later)
FLAG <- c(USA="🇺🇸", GBR="🇬🇧", EU27="🇪🇺", JPN="🇯🇵", CAN="🇨🇦")

# a clean default ggplot theme I like
theme_pub <- function(base_size = 14){
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold", size = base_size + 4),
      plot.subtitle = element_text(color = COL_GREY),
      plot.caption  = element_text(color = COL_GREY, size = base_size - 2, hjust = 0),
      axis.title    = element_text(color = "#111"),
      axis.text     = element_text(color = "#111"),
      panel.grid.minor = element_blank()
    )
}

# LinkedIn portrait = tighter margins + slightly smaller text
theme_pub_social <- function(base_size = 12){
  theme_pub(base_size) +
    theme(
      plot.title    = element_text(size = base_size + 8, face = "bold"),
      plot.subtitle = element_text(size = base_size + 2, colour = COL_GREY),
      axis.title    = element_text(size = base_size + 1),
      axis.text.x   = element_text(size = base_size - 1),
      legend.position = "bottom",
      legend.title    = element_text(face = "bold"),
      plot.margin     = margin(14, 18, 18, 18)
    )
}

# one caption string so I don’t duplicate it 20 times
CAPTION <- "Independent analysis • Data: Climate Watch (WRI) + NDC sources"


# ---- 2) project paths + small toggles ---------------------------------------
# if here() can’t find the repo root, open the .Rproj or run here::set_here() once
if (!dir.exists(here())) {
  stop("here() can't see my project root. Open the .Rproj or run here::set_here() once.")
}

RAW_DIR   <- here("raw_data")
OUT_DIR   <- here("output","figures")
OUT_LINES <- here("output","figures","country_lines")
dir.create(OUT_LINES, recursive = TRUE, showWarnings = FALSE)

# keep it bite-sized for now
COUNTRIES <- c("USA","GBR","EU27","JPN","CAN")

# this is my smoothing choice for the 2015 baseline
USE_THREE_YEAR_AVG <- TRUE

# even if nobody is truly “on track”, keep a green legend key
FORCE_GREEN_LEGEND <- TRUE


# ---- 3) load Climate Watch emissions ----------------------------------------
# I manually downloaded CW_* files. I want the harmonized ClimateWatch one.
EMISS_PATH <- here("raw_data","CW_HistoricalEmissions_ClimateWatch.csv")
if (!file.exists(EMISS_PATH)) {
  picks <- list.files(RAW_DIR, pattern="^CW_HistoricalEmissions_.*ClimateWatch.*\\.csv$", full.names=TRUE)
  if (length(picks) == 0) stop("I can't find a Climate Watch emissions CSV in raw_data/.")
  EMISS_PATH <- picks[1]
}
message("Using emissions file: ", basename(EMISS_PATH))

# read wide; janitor makes column names snake_case; years look like 1990..2022 or x1990..x2022
raw_cw <- readr::read_csv(EMISS_PATH, show_col_types = FALSE) |> clean_names()

# find all the wide year columns (this regex catches 1990..2099, with optional 'x' prefix)
year_cols <- grep("^x?(19|20)[0-9]{2}$", names(raw_cw), value = TRUE)
if (length(year_cols) == 0) {
  message("Column names I see:\n", paste(head(names(raw_cw), 40), collapse = ", "))
  stop("Expected year columns like x1990..x2022 (or 1990..2022)")
}

# go from wide → long; also strip the 'x' off “x1990”
long <- raw_cw |>
  tidyr::pivot_longer(all_of(year_cols), names_to = "year", values_to = "value_mtco2e") |>
  mutate(year = as.integer(gsub("^x", "", year)))

# I only want: sector = total incl/excl LULUCF and gas = All GHG (or Kyoto)
if (!all(c("sector","gas") %in% names(long))) {
  stop("I expected 'sector' and 'gas' columns in the Climate Watch file")
}

has_excl <- grepl("total", long$sector, TRUE) &
  grepl("excl",  long$sector, TRUE) &
  grepl("lu?l?ucf", long$sector, TRUE)
has_incl <- grepl("total", long$sector, TRUE) &
  grepl("incl",  long$sector, TRUE) &
  grepl("lu?l?ucf", long$sector, TRUE)

# prefer excluding LULUCF; otherwise fall back to including
if (any(has_excl, na.rm = TRUE)) {
  sector_keep <- has_excl;  sector_label <- "Total excluding LULUCF"
} else if (any(has_incl, na.rm = TRUE)) {
  warning("Could not find 'Total excluding LULUCF'. Using 'Total including LULUCF' instead.")
  sector_keep <- has_incl;  sector_label <- "Total including LULUCF"
} else {
  stop("I can't find any 'Total ... LULUCF' sector. Check unique(long$sector).")
}
gas_keep <- grepl("all|kyoto|ghg", long$gas, ignore.case = TRUE)

# which column looks like “country”?
country_col <- if ("country" %in% names(long)) "country" else {
  cn <- names(long)[grepl("country|location|region|territory|area|iso", names(long), ignore.case = TRUE)]
  if (length(cn) == 0) stop("I can't find a country-like column")
  cn[1]
}

# are values already ISO3? (>=90% look like 'USA', 'JPN', etc.)
vals <- toupper(trimws(long[[country_col]]))
is_iso3ish <- mean(grepl("^[A-Z]{3}$", na.omit(vals))) >= 0.9

if (is_iso3ish) {
  # case A: codes are already ISO3; normalize EU variants to “EU27”
  emis0 <- long |>
    filter(sector_keep & gas_keep) |>
    transmute(iso3_raw = toupper(.data[[country_col]]), year, value_mtco2e) |>
    mutate(iso3 = case_when(iso3_raw %in% c("EUU","EU27","EU28","E27","E28","EUR") ~ "EU27",
                            TRUE ~ iso3_raw))
} else {
  # case B: names not codes → map a few patterns just for my study set
  country_patterns <- tribble(
    ~pattern,                                                         ~iso3,
    "^UNITED\\s+STATES",                                              "USA",
    "^UNITED\\s+KINGDOM|GREAT\\s+BRITAIN|NORTHERN\\s+IRELAND",        "GBR",
    "^EUROPEAN\\s+UNION(\\s*\\(27\\))?$",                             "EU27",
    "^JAPAN$",                                                        "JPN",
    "^CANADA$",                                                       "CAN"
  )
  map_to_iso3 <- function(x) {
    out <- rep(NA_character_, length(x))
    for (i in seq_len(nrow(country_patterns))) {
      hit <- grepl(country_patterns$pattern[i], x, ignore.case = TRUE)
      out[is.na(out) & hit] <- country_patterns$iso3[i]
    }
    out
  }
  emis0 <- long |>
    filter(sector_keep & gas_keep) |>
    mutate(iso3 = map_to_iso3(toupper(trimws(.data[[country_col]])))) |>
    filter(!is.na(iso3)) |>
    transmute(iso3, year, value_mtco2e)
}

# little peek before filtering to my 5-country study set
message("Top codes present after sector/gas filter (before study-set filter):")
print(emis0 |> count(iso3, sort = TRUE) |> head(30))

# now keep only the study set and add pretty country names
emis <- emis0 |>
  filter(iso3 %in% COUNTRIES) |>
  mutate(country = recode(iso3,
                          USA="United States", GBR="United Kingdom",
                          EU27="European Union (27)", JPN="Japan", CAN="Canada")) |>
  select(iso3, country, year, value_mtco2e)

# guardrail: if zero rows, my EU code mapping is probably off
if (nrow(emis) == 0) {
  message("After filtering to COUNTRIES = {", paste(COUNTRIES, collapse = ", "), "} there are 0 rows.")
  stop("No rows for the chosen study set. Check EU code mapping (EUU→EU27) or COUNTRIES.")
}
message("Rows after filtering to study set: ", nrow(emis))
print(count(emis, iso3))


# ---- 4) load my tiny targets.csv -------------------------------------------
# This is the small hand-typed file that says “GBR base=1990 reduce 68% by 2030”, etc.
TGT_PATH <- here("raw_data","targets.csv")
if (!file.exists(TGT_PATH)) stop("I need raw_data/targets.csv. See README for the template.")
TGT <- readr::read_csv(TGT_PATH, show_col_types = FALSE) |> rename_with(tolower)


# ---- 5) helper functions I’ll forget the formulas for -----------------------
# three-year mean around a center year (e.g., 2014–2016 around 2015)
three_year_mean <- function(series_named_by_year, center_year){
  yrs <- c(center_year-1, center_year, center_year+1)
  mean(series_named_by_year[as.character(yrs)], na.rm = TRUE)
}

# CAGR (compound annual growth rate): average yearly change from e0→e1 in N years
cagr <- function(e0, e1, yrs){
  if (is.na(e0) || is.na(e1) || e0 <= 0 || e1 <= 0 || yrs <= 0) return(NA_real_)
  (e1/e0)^(1/yrs) - 1
}

# friendly % formatter
fmt_pct <- function(x, acc = 0.1){
  if (is.finite(x)) scales::percent(x, accuracy = acc) else "n/a"
}


# ---- 6) loop countries → compute “on track?” → make plots -------------------
results <- list()

for (cc in COUNTRIES) {
  ser <- emis |> filter(iso3 == cc) |> arrange(year)
  if (nrow(ser) == 0 || !(2015 %in% ser$year)) { message("Skipping ", cc); next }
  s <- setNames(ser$value_mtco2e, ser$year)
  
  # 2015 baseline (optionally smoothed)
  e2015 <- if (USE_THREE_YEAR_AVG) three_year_mean(s, 2015) else s["2015"]
  latest_year <- max(ser$year, na.rm = TRUE)
  e_latest <- s[as.character(latest_year)]
  
  # grab the first matching row from targets.csv for this country
  trow <- TGT |> filter(toupper(iso3) == cc) |> slice_head(n = 1)
  if (nrow(trow) == 0) { message("No target row for ", cc); next }
  
  # turn the *type of target* into an absolute 2030 level (MtCO2e)
  if ("target_abs_excl_lulucf_mtco2e" %in% names(trow) && !is.na(trow$target_abs_excl_lulucf_mtco2e)) {
    e2030 <- as.numeric(trow$target_abs_excl_lulucf_mtco2e)   # easy path: already absolute
  } else {
    # percent below base year path (e.g., “-55% vs 1990”)
    if (is.na(trow$base_year) || is.na(trow$reduction_pct)) { message(cc, ": target missing info"); next }
    base_val <- s[as.character(trow$base_year)]
    if (is.na(base_val)) { message(cc, ": base year not found in emissions"); next }
    e2030 <- base_val * (1 - as.numeric(trow$reduction_pct)/100)
  }
  
  # (A) observed decline from 2015→latest, (B) required decline from 2015→2030
  r_obs <- cagr(e2015, e_latest, latest_year - 2015)
  r_req <- cagr(e2015, e2030, 2030 - 2015)
  
  # if we keep the *observed* pace, where do we land in 2030?
  proj2030 <- ifelse(is.na(r_obs), NA_real_, e2015 * (1 + r_obs)^(2030 - 2015))
  
  # on_track rule: observed decline is at least as steep as required decline
  on_track <- (!is.na(r_obs) && !is.na(r_req) && r_obs <= r_req)
  
  # stash a per-country summary row for the bar chart later
  results[[length(results)+1]] <- tibble(
    iso3 = cc,
    country = ser$country[1],
    latest_year = latest_year,
    E2015 = e2015, E_latest = e_latest, E2030_target = e2030,
    r_obs = r_obs, r_req = r_req,
    proj_2030 = proj2030,
    delta_2030 = proj2030 - e2030,   # negative = better than target
    on_track = on_track
  )
  
  # ---- chart for this country ----
  # ---- chart for this country ----
  status <- factor(if (on_track) "On Track" else "Off Track",
                   levels = c("On Track","Off Track"))
  
  subtitle_txt <- sprintf("Observed ≈ %s/yr vs required ≈ %s/yr",
                          fmt_pct(r_obs, 0.1), fmt_pct(r_req, 0.1))
  
  g <- ggplot(ser, aes(year, value_mtco2e)) +
    # history
    geom_line(linewidth = 1.2, color = COL_LINE) +
    # straight line from 2015 baseline to 2030 target
    annotate("segment", x = 2015, xend = 2030, y = e2015, yend = e2030,
             linetype = "dashed", linewidth = 0.9, color = COL_GREY) +
    # actual 2030 target dot
    geom_point(
      data = tibble(year = 2030, value = e2030, status = status),
      aes(x = year, y = value, fill = status),
      shape = 21, size = 4.5, stroke = 1.2, color = "black"
    ) +
    # >>> force the green legend key, even if nobody is on-track
    geom_point(
      data = tibble(
        year   = min(ser$year),                     # valid coords to avoid warnings
        value  = min(ser$value_mtco2e),
        status = factor("On Track", levels = c("On Track","Off Track"))
      ),
      aes(x = year, y = value, fill = status),
      shape = 21, size = 4.5, stroke = 1.2, color = "black",
      alpha = 0, inherit.aes = FALSE, show.legend = TRUE
    ) +
    # legend styling (keeps both keys)
    scale_fill_manual(
      values = c("On Track" = COL_ON, "Off Track" = COL_OFF),
      breaks = c("On Track","Off Track"),
      drop   = FALSE,
      name   = "2030 Target Status",
      guide  = guide_legend(
        override.aes = list(shape = 21, colour = "black", size = 4, stroke = 1.2, alpha = 1)
      )
    ) +
    # flag watermark
    annotate("text", x = min(ser$year) + 1, y = max(ser$value_mtco2e),
             label = FLAG[cc], hjust = 0, vjust = 1, alpha = 0.25, size = 10) +
    # axes
    scale_x_continuous(breaks = scales::pretty_breaks(8)) +
    scale_y_continuous(labels = scales::label_comma(),
                       expand = expansion(mult = c(0.02, 0.10))) +
    coord_cartesian(clip = "off") +
    labs(
      title    = paste0(ser$country[1], " — Emissions since 2015 vs 2030 target (", sector_label, ")"),
      subtitle = subtitle_txt,
      x = "Year", y = "MtCO\u2082e (GHG)", caption = CAPTION
    ) +
    theme_pub(14) +
    theme(legend.position = "bottom")
  
  # save (normal landscape for the repo)
  ggsave(here("output","figures","country_lines", paste0(cc, "_line.png")),
         g, width = 10, height = 6, dpi = 220, bg = "white")
  
  # save (LinkedIn landscape: roomy bottom for legend, nothing clips)
  g_linkedin <- g +
    theme_pub(16) +
    theme(
      plot.margin       = margin(20, 32, 36, 24),
      legend.box.margin = margin(6, 0, 0, 0),
      legend.spacing.x  = unit(8, "pt")
    )
  
  ggsave(here("output","figures","country_lines", paste0(cc, "_line_linkedin.png")),
         plot = g_linkedin, width = 1920, height = 1080, units = "px",
         dpi = 320, bg = "white")
  
}

# quick sanity drop: a CSV I can open in a spreadsheet if something looks off
summary_df <- bind_rows(results) |>
  arrange(delta_2030) |>
  mutate(on_track = as.logical(on_track),
         label_country = paste(FLAG[iso3], country))
readr::write_csv(summary_df, here("output","summary_ontrack.csv"))

# ---- 7) build the summary + bar chart (robust version) ----------------------

# combine country results
summary_df <- bind_rows(results)

# quick guardrails so errors are informative
if (is.null(summary_df) || nrow(summary_df) == 0) {
  stop("No per-country results were produced. Check that targets.csv covers all COUNTRIES.")
}
if (!all(c("iso3","country","delta_2030","on_track") %in% names(summary_df))) {
  stop("Expected columns missing in summary_df. Inspect names(summary_df).")
}

# make a clean plotting table
bar_df <- summary_df |>
  mutate(
    on_track      = as.logical(on_track),
    label_country = paste(FLAG[iso3], country),
    delta_2030    = suppressWarnings(as.numeric(delta_2030))  # ensure numeric
  ) |>
  filter(is.finite(delta_2030)) |>                # drop NAs/Infs so ggplot doesn't choke
  arrange(delta_2030) |>
  mutate(label_country = factor(label_country, levels = unique(label_country)))

if (nrow(bar_df) == 0) {
  stop("All delta_2030 are NA/Inf; check target math (base_year present? reduction_pct numeric?).")
}

# precompute labels OUTSIDE aes to avoid scoping issues
max_delta <- max(bar_df$delta_2030, na.rm = TRUE)
bar_df <- bar_df |>
  mutate(
    num_label = scales::comma(round(delta_2030, 0)),
    tag = dplyr::case_when(
      delta_2030 <= 0   ~ "ahead of target",
      delta_2030 > 1000 ~ "far off track",
      delta_2030 > 300  ~ "needs big acceleration",
      TRUE              ~ "needs acceleration"
    ),
    tag_x   = delta_2030 + ifelse(delta_2030 >= 0, 0.10, -0.10) * max_delta,
    tag_hj  = ifelse(delta_2030 >= 0, 0, 1),
    num_hj  = ifelse(delta_2030 >= 0, -0.15, 1.15)
  )

# plot
bar <- ggplot(bar_df, aes(y = label_country, x = delta_2030, fill = on_track)) +
  annotate("rect", xmin = -Inf, xmax = 0, ymin = -Inf, ymax = Inf,
           fill = scales::alpha(COL_ON, 0.06), color = NA) +
  geom_col() +
  geom_vline(xintercept = 0, linewidth = 0.6, color = COL_GREY) +
  scale_fill_manual(values = c(`TRUE` = COL_ON, `FALSE` = COL_OFF), guide = "none") +
  geom_text(aes(label = num_label, hjust = num_hj),
            size = 3.2, fontface = "bold") +
  geom_text(aes(x = tag_x, label = tag, hjust = tag_hj),
            size = 3.6, color = COL_GREY) +
  scale_x_continuous(
    breaks = scales::pretty_breaks(8),
    labels = scales::label_comma(),
    expand = expansion(mult = c(0.04, 0.40))
  ) +
  labs(
    title    = "Projected 2030 Emissions vs Pledged Targets",
    subtitle = "Bars show: projected 2030 at today’s pace minus 2030 target (negative = better than target)",
    x = "MtCO\u2082e", y = NULL,
    caption = CAPTION
  ) +
  coord_cartesian(clip = "off") +
  theme_pub(15) +
  theme(plot.title = element_text(face = "bold"))

# repo landscape
ggsave(here("output","figures","ontrack_bar.png"),
       bar, width = 12, height = 7, dpi = 220, bg = "white")

# LinkedIn landscape
bar_linkedin <- bar +
  theme_pub(16) +
  theme(
    plot.margin = margin(20, 32, 28, 24)
  )

ggsave(here("output","figures","ontrack_bar_linkedin.png"),
       bar_linkedin, width = 1920, height = 1080, units = "px",
       dpi = 320, bg = "white")

message("Done! Charts in output/figures/. Summary table at output/summary_ontrack.csv")

# for reproducibility later if something changes on my machine
capture.output(sessionInfo(), file = here("output","session_info.txt"))