# Paris Agreement – Emissions vs Targets (Part 1: 2015–2024)

![Status](https://img.shields.io/badge/status-in--progress-yellow)
![License](https://img.shields.io/badge/license-MIT-blue)
![R](https://img.shields.io/badge/R-276DC3?logo=r&logoColor=white)

### Why this project?

I built this project to bring together my data analytics training and my interest in global policy.  
I’ve always wondered whether climate pledges translate into real progress, so I set out to test it myself: pulling open emissions data, writing reproducible R code, and creating charts that make the gap between promises and reality visible at a glance.  
It’s both a technical exercise in tidyverse workflows and a policy-relevant analysis with real-world stakes.

**Status:** 🚧 *In Progress* (Full release planned Oct 2025)  

This repo is **Part 1** of my Paris Agreement project.  
Here, I compare **countries’ pledged emissions reduction targets (NDCs)** with **actual GHG emissions since 2015**.  
The aim is to show, in data and visuals, who is:

- ✅ On track (meeting or beating their pathway)  
- ⚠️ Lagging (falling short of commitments)  
- ❌ Off course (emissions rising despite pledges)  

![On/off track bar chart](output/figures/ontrack_bar.png)
*Projected 2030 emissions vs pledged targets (negative = better than target)*  

Part 2 (coming later) will expand into **climate finance vs emissions** to ask: *“Who is funding climate action, and who is emitting the most?”*

---

### 📊 Planned Deliverables
- **Line charts** — Actual emissions vs pledged 2030 pathway  
- **Bar chart** — Projected 2030 emissions minus pledged target  
- **Narrative insights** — Who’s keeping promises under Paris?

---

### 🚀 Quickstart

Clone this repo and open the R Project:

```bash
git clone https://github.com/phoebelamb411/Paris_Agreement_Part_1.git
cd Paris_Agreement_Part_1
```
Then in R
```
# Install dependencies
install.packages(c("tidyverse","janitor","here","scales"))

# Run main script
source("scripts/make_charts.R")
```
Outputs will appear in output/figures/ and output/summary_ontrack.csv.

---

### 🌍 Data Sources
- UNFCCC NDC Registry (official targets)
- Climate Action Tracker (progress summaries)  
- Climate Watch (WRI, historical GHG emissions)  

---

### 🔧 Tools & Skills
- Data wrangling with dplyr and tidyr
- Data cleaning with janitor
- File-safe project paths with here
- Data visualization with ggplot2 (line & bar charts)
- Reproducible workflow design in R Projects

---

### 🗂️ Structure
```
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
│ │    ├─ USA_line.png
│ │    └─ GBR_line.png
| |    └─...
│ └─ summary_ontrack.csv # table with metrics per country
| └─ summary_ontrack_data_dictionary.md
├─ scripts/
│ └─ make_charts.R # run me
├─ .gitignore
└─ Paris_Agreement_Part_1.Rproj
```
---

### 📄 `targets.csv` Schema (what I fill)

```csv
iso3,country,target_year,target_abs_excl_lulucf_mtco2e,target_type,base_year,reduction_pct,source
USA,United States,2030,,% below base year,2005,51,<link>
GBR,United Kingdom,2030,,% below base year,1990,68,<link>
EU27,European Union (27),2030,,% below base year,1990,55,<link>
JPN,Japan,2030,,% below base year,2013,46,<link>
CAN,Canada,2030,,% below base year,2005,40,<link>
```
If I can find a direct absolute 2030 target (excl. LULUCF), I put that in target_abs_excl_lulucf_mtco2e and leave %/base_year blank.
Otherwise, I use “% below base year” + the base year, and the script computes the absolute 2030 target.

---

### 🧠 Method (plain English)

1. Use GHG totals excluding LULUCF (for comparability).
2. Observed rate: How fast emissions have fallen since 2015 (compounded annual rate, optional 3-year smoothing around 2015).
3. Required rate: How fast they must fall from 2015 → 2030 to hit the target.
4. On track if observed ≤ required (i.e., cutting fast enough).
5. Bonus metric: Projected 2030 if the observed trend continues, then compare to the target (→ bar chart).

---

### 🔎 Early Results (independent analysis)

  ### Early Results (Summary Table)

| Country         | Target (2030)            | Observed Trend (since 2015) | Status     |
|-----------------|--------------------------|-----------------------------|------------|
| 🇺🇸 United States | -50% vs 2005             | Decline too slow             | Off Track  |
| 🇬🇧 United Kingdom| -68% vs 1990             | Decline on pace              | On Track   |
| 🇪🇺 European Union (27) | -55% vs 1990        | Decline slower than needed   | Off Track  |
| 🇯🇵 Japan         | -46% vs 2013             | Decline lagging              | Off Track  |
| 🇨🇦 Canada        | -40–45% vs 2005          | Decline slower than needed   | Off Track  |

*(Values illustrative — table auto-updates from `summary_ontrack.csv` if you refresh and re-paste the numbers.)*

Running the pipeline on five study cases (**USA, UK, EU27, Japan, Canada**) gives some interesting first takeaways:

### 🇺🇸 United States (USA)  
- **Baseline (2015):** ≈ 6,500 MtCO₂e  
- **Target:** 50–52% below 2005 levels by 2030  
- **Reality:** Emissions dipped during COVID but have since rebounded.  
  The observed decline rate is slower than required → the U.S. is **not on track** for its 2030 pledge.  

### 🇬🇧 United Kingdom (GBR)  
- **Target:** ≈ 68% below 1990 by 2030  
- **Observed trend:** Declines continue, but the required annual reduction pace is steeper than current progress.  
  Historically strong reductions, but currently **lagging**.  

### 🇪🇺 European Union (EU27)  
- **Target:** 55% below 1990 by 2030  
- **Observed trend:** The EU has cut emissions significantly since 1990 and continues to decline.  
  Since 2015, the pace is slightly behind the required trajectory → **caution zone**, not comfortably on track.  

### 🇯🇵 Japan (JPN)  
- **Target:** 46% below 2013 by 2030  
- **Observed trend:** Emissions are falling modestly, but the trajectory suggests Japan risks overshooting its 2030 target unless reductions accelerate.  

### 🇨🇦 Canada (CAN)  
- **Target:** 40–45% below 2005 by 2030  
- **Observed trend:** Emissions remain stubbornly flat, with only minor declines.  
  Canada is **off course**, with the gap to target widening if the current pace holds.  
  
Note: These are preliminary findings from my personal pipeline. Values are rounded, and future iterations will refine them with updated datasets.

---

### 📊 What the bar chart shows

The on/off-track bar chart compares:  
- **Projected 2030 at today’s pace** vs  
- **Pledged 2030 target**  

- **Negative bars = better than target**  
- **Positive bars = falling short**  

---

### ⚠️ Caveats (being transparent)

Target scopes differ (some include LULUCF or exclude sectors). I try to use economy-wide excl. LULUCF where possible and clearly note sources.
COVID & shocks: 2015 baseline can be noisy; I optionally smooth with a 3-year average.
Different datasets (UNFCCC, PRIMAP, GCP) vary slightly. For v1 I default to Climate Watch and document deviations.
Intensity/BAU/peaking targets aren’t handled yet (future work).

---

### 📁 Outputs

- `output/summary_ontrack.csv` – country-level results (emissions, targets, projections).
- `output/summary_ontrack_data_dictionary.md` – plain-English notes describing each column.
- `output/figures/` – contains per-country line charts and the overall on/off-track bar chart.

---

## Sample Outputs

Here are two example charts generated by the analysis:

**United States: Emissions since 2015 vs 2030 Target**

![USA line chart](output/figures/country_lines/USA_line.png)

![EU line chart](output/figures/country_lines/EU27_line.png)

---

### 🔗 Quick Links to Results

👉 [Summary CSV](output/summary_ontrack.csv)  
👉 [On/Off-track Bar Chart](output/figures/ontrack_bar.png)  
👉 [All Country Line Charts](output/figures/country_lines/)  

---

### 🔮 Next Steps
- Add more countries beyond the initial 5
- Explore sector-specific targets (e.g., power, transport)
- Compare across multiple emissions datasets (UNFCCC, PRIMAP)
- Expand Part 2: climate finance vs emissions

---

### 🗓️ Timeline
- Repo created: September 2025  
- Data cleaning & pipeline: Sept–Oct 2025  
- Visualizations & analysis: October 2025  
- **Final release (Part 1): Early Oct 2025**

---

### 📝 Citation

Please cite the original data providers:
- [Climate Watch (WRI) – Historical GHG Emissions](https://www.climatewatchdata.org/ghg-emissions) Accessed: September 2025
- [UNFCCC NDC Registry](https://unfccc.int/NDCREG) Nationally Determined Contributions.
- [Climate Action Tracker (CAT)](https://climateactiontracker.org) Country assessments and data.

I’ll list per-country URLs in targets.csv and link them in the final write-up.

---

### 🔐 License & Use

Code: [MIT License](./LICENSE)
Data: Respect original providers’ terms. Climate Watch data are open with attribution; UNFCCC/CAT terms apply to their content and figures.

---

### ✨ Why This Matters
The Paris Agreement is the world’s most important climate pact.  
But **targets mean little without accountability**.  

This project provides a transparent, data-driven look at whether countries are on track to meet their own climate promises.

---

### ✅ Roadmap

**Done**
- [x] Finish emissions data wrangling (Climate Watch)  
- [x] Finalize `targets.csv` with reliable NDC sources  
- [x] Generate country line charts  
- [x] Generate on/off track bar chart  

**To Do**
- [ ] Write narrative insights  
- [ ] Draft Part 2 (climate finance vs emissions)

---

### 📌 Part 2 (coming soon)
In Part 2, I’ll explore **climate finance vs emissions** — comparing who pays into climate finance vs who emits the most.  

Stay tuned!

### 🤝 Let's Connect

- 💼 [LinkedIn](https://www.linkedin.com/in/phoebelamb)  
- 🐙 [GitHub](https://github.com/phoebelamb411) 