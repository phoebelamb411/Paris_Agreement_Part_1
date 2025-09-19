# Paris Agreement – Emissions vs Targets (Part 1: 2015–2024)

![Status](https://img.shields.io/badge/status-in--progress-yellow)
![License](https://img.shields.io/badge/license-MIT-blue)

**Status:** 🚧 *In Progress* (Full release planned Oct 2025)  

This repo is **Part 1** of my Paris Agreement project.  
Here, I compare **countries’ pledged emissions reduction targets (NDCs)** with **actual GHG emissions since 2015**.  
The aim is to show, in data and visuals, who is:

- ✅ On track (meeting or beating their pathway)  
- ⚠️ Lagging (falling short of commitments)  
- ❌ Off course (emissions rising despite pledges)  

Part 2 (coming later) will expand into **climate finance vs emissions** to ask: *“Who is funding climate action, and who is emitting the most?”*

---

## 📊 Planned Deliverables
- **Line charts** — Actual emissions vs pledged 2030 pathway  
- **Bar chart** — Projected 2030 emissions minus pledged target  
- **Narrative insights** — Who’s keeping promises under Paris?

---

## 🌍 Data Sources
- UNFCCC NDC Registry (official targets)  
- Climate Action Tracker (progress summaries)  
- Climate Watch (WRI, historical GHG emissions)  

---

## 🔧 Tools & Skills
- **R (tidyverse, ggplot2)**  
- Data wrangling & visualization  
- Reproducible research workflows  
- Data storytelling  

---

## 🗂️ Structure

paris-agreement-part1/
├─ raw_data/ # raw downloads (kept as-is)
│ ├─ CW_HistoricalEmissions_ClimateWatch.csv
│ ├─ CW_HistoricalEmissions_UNFCCC.csv (optional variants)
│ ├─ CW_HistoricalEmissions_PRIMAP.csv (optional variants)
│ ├─ metadata.csv
│ └─ targets.csv # tiny file I fill with 2030 targets for a few countries
├─ output/
│ ├─ figures/
│ │ ├─ ontrack_bar.png
│ │ └─ country_lines/
│ │ ├─ USA_line.png
│ │ └─ ...
│ └─ summary_ontrack.csv # table with metrics per country
├─ scripts/
│ └─ make_charts.R # run me
└─ Paris_Agreement_Part_1.Rproj

---

## 📄 `targets.csv` Schema (what I fill)

```csv
iso3,country,target_year,target_abs_excl_lulucf_mtco2e,target_type,base_year,reduction_pct,source
USA,United States,2030,,% below base year,2005,51,<link>
GBR,United Kingdom,2030,,% below base year,1990,68,<link>
EU27,European Union (27),2030,,% below base year,1990,55,<link>
JPN,Japan,2030,,% below base year,2013,46,<link>
CAN,Canada,2030,,% below base year,2005,40,<link>

If I can find a direct absolute 2030 target (excl. LULUCF), I put that in target_abs_excl_lulucf_mtco2e and leave %/base_year blank.

Otherwise, I use “% below base year” + the base year, and the script computes the absolute 2030 target.

---

🧠 Method (plain English)

Use GHG totals excluding LULUCF (for comparability).

Observed rate: How fast emissions have fallen since 2015 (compounded annual rate, optional 3-year smoothing around 2015).

Required rate: How fast they must fall from 2015 → 2030 to hit the target.

On track if observed ≤ required (i.e., cutting fast enough).

Bonus metric: Projected 2030 if the observed trend continues, then compare to the target (→ bar chart).

---

⚠️ Caveats (being transparent)

Target scopes differ (some include LULUCF or exclude sectors). I try to use economy-wide excl. LULUCF where possible and clearly note sources.

COVID & shocks: 2015 baseline can be noisy; I optionally smooth with a 3-year average.

Different datasets (UNFCCC, PRIMAP, GCP) vary slightly. For v1 I default to Climate Watch and document deviations.

Intensity/BAU/peaking targets aren’t handled yet (future work).

---

## 🗓️ Timeline
- Repo created: September 2025  
- Data cleaning & pipeline: Sept–Oct 2025  
- Visualizations & analysis: October 2025  
- **Final release (Part 1): Late Oct 2025**

---

📝 Citation

Please cite the original data providers:
Climate Watch (WRI). Historical GHG Emissions. Accessed: Month Year.
UNFCCC NDC Registry. Nationally Determined Contributions.
Climate Action Tracker (CAT). Country assessments and data.

I’ll list per-country URLs in targets.csv and link them in the final write-up.

---

🔐 License & Use

Code: MIT License (TBD)
Data: Respect original providers’ terms. Climate Watch data are open with attribution; UNFCCC/CAT terms apply to their content and figures.

---

## ✨ Why This Matters
The Paris Agreement is the world’s most important climate pact.  
But **targets mean little without accountability**.  

This project provides a transparent, data-driven look at whether countries are on track to meet their own climate promises.

---

## ✅ Roadmap
- [ ] Finish emissions data wrangling (Climate Watch)  
- [ ] Finalize `targets.csv` with reliable NDC sources  
- [ ] Generate country line charts  
- [ ] Generate on/off track bar chart  
- [ ] Write narrative insights  

---

## 📌 Part 2 (coming soon)
In Part 2, I’ll explore **climate finance vs emissions** — comparing who pays into climate finance vs who emits the most.  

Stay tuned!