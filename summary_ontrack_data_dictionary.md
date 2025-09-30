# summary_ontrack.csv — column notes (plain English)

- iso3: three-letter code (I normalize EU variants to EU27)
- country: pretty name I use on charts
- latest_year: last year available for that country
- E2015: my 2015 baseline (3-year mean if smoothing is on)
- E_latest: emissions at latest_year
- E2030_target: absolute 2030 target level (computed from targets.csv)
- r_obs: observed average yearly change since 2015 (CAGR)
- r_req: required average yearly change 2015→2030 to hit target
- proj_2030: where 2030 lands if the observed rate continues
- delta_2030: proj_2030 − E2030_target (negative = better than target)
- on_track: TRUE if observed decline is at least as fast as required
