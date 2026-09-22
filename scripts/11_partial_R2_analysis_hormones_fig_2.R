# Load the reusable mixed-model analysis function
source("scripts/part_r2_analysis_func.R")

# Common config for all vars
nboot = 1000

# Load the TSV dataset
df_hi_ghrelin_final <- read.delim(
  "data/df_GI_bid_hi_ac_Ghrelin_Totale_no_outliers_session.tsv",
  header = TRUE,
  sep = "\t",
  stringsAsFactors = FALSE
)

# Create IMC baseline centered variable
df_hi_ghrelin_final$IMC_baseline_centered <- df_hi_ghrelin_final$IMC_baseline - mean(df_hi_ghrelin_final$IMC_baseline, na.rm = TRUE)

# Create baseline age from each participant's session 1 measurement
session_one <- df_hi_ghrelin_final[
  as.character(df_hi_ghrelin_final$session) == "1" &
    !is.na(df_hi_ghrelin_final$age),
  c("id_participant", "age")
]

# Keep one session 1 age per participant
session_one <- session_one[
  !duplicated(session_one$id_participant),
]

# Map each participant's baseline age to all of their rows
df_hi_ghrelin_final$age_baseline <- session_one$age[
  match(
    df_hi_ghrelin_final$id_participant,
    session_one$id_participant
  )
]

# For participants without session 1 age, use their first available age
missing_baseline_age <- is.na(df_hi_ghrelin_final$age_baseline)

df_hi_ghrelin_final$age_baseline[missing_baseline_age] <- ave(
  df_hi_ghrelin_final$age[missing_baseline_age],
  df_hi_ghrelin_final$id_participant[missing_baseline_age],
  FUN = function(values) {
    available_values <- values[!is.na(values)]

    if (length(available_values) > 0) {
      available_values[1]
    } else {
      NA_real_
    }
  }
)

# Center baseline age around the sample mean
df_hi_ghrelin_final$age_baseline_centered <-
  df_hi_ghrelin_final$age_baseline -
  mean(df_hi_ghrelin_final$age_baseline, na.rm = TRUE)


# Define the mixed-effects model
bid_formula <- bid ~ Ghrelin_Totale +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request the continuous hormones predictor and covariates
hormones_partvars <- c(
  "Ghrelin_Totale",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
Ghrelin_Totale_analysis <- run_mixed_model_analysis(
  data = df_hi_ghrelin_final,
  formula = bid ~ Ghrelin_Totale +
    IMC_baseline_centered +
    age_baseline_centered +
    type_chx +
    sexeF +
    (1 | id_participant),
  group_col = "id_participant",
  factor_levels = list(
    type_chx = c("1", "2", "3")
  ),
  partvars = hormones_partvars,
  partbatch = NULL,
  R2_type = "marginal",
  max_level = 1,
  emmeans_terms = NULL,
  power_terms = NULL,
  nboot = nboot,
  seed = 1234,
  show_plots = TRUE,
  parallel = TRUE,
  workers = 4
)

# Display part-R2 results
summary(
  Ghrelin_Totale_analysis$part_r2,
  ests = TRUE,
  round_to = 3
)

# Display residual normality results from the overall analysis
Ghrelin_Totale_analysis$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
Ghrelin_Totale_analysis$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
Ghrelin_Totale_analysis$vif

# Display omnibus ANOVA F-tests
Ghrelin_Totale_analysis$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
Ghrelin_Totale_analysis$coefficients

# Display fixed-effect confidence intervals
Ghrelin_Totale_analysis$confidence_intervals

# Display R and package versions
Ghrelin_Totale_analysis$reproducibility


# Hormones GLP-1

# Load the TSV dataset
df_hi_GLP_1_final <- read.delim(
  "data/df_GI_bid_hi_pp_GLP1_no_outliers_session.tsv",
  header = TRUE,
  sep = "\t",
  stringsAsFactors = FALSE
)

# Create IMC baseline centered variable
df_hi_GLP_1_final$IMC_baseline_centered <- df_hi_GLP_1_final$IMC_baseline - mean(df_hi_GLP_1_final$IMC_baseline, na.rm = TRUE)

# Create baseline age from each participant's session 1 measurement
session_one <- df_hi_GLP_1_final[
  as.character(df_hi_GLP_1_final$session) == "1" &
    !is.na(df_hi_GLP_1_final$age),
  c("id_participant", "age")
]

# Keep one session 1 age per participant
session_one <- session_one[
  !duplicated(session_one$id_participant),
]

# Map each participant's baseline age to all of their rows
df_hi_GLP_1_final$age_baseline <- session_one$age[
  match(
    df_hi_GLP_1_final$id_participant,
    session_one$id_participant
  )
]

# For participants without session 1 age, use their first available age
missing_baseline_age <- is.na(df_hi_GLP_1_final$age_baseline)

df_hi_GLP_1_final$age_baseline[missing_baseline_age] <- ave(
  df_hi_GLP_1_final$age[missing_baseline_age],
  df_hi_GLP_1_final$id_participant[missing_baseline_age],
  FUN = function(values) {
    available_values <- values[!is.na(values)]

    if (length(available_values) > 0) {
      available_values[1]
    } else {
      NA_real_
    }
  }
)

# Center baseline age around the sample mean
df_hi_GLP_1_final$age_baseline_centered <-
  df_hi_GLP_1_final$age_baseline -
  mean(df_hi_GLP_1_final$age_baseline, na.rm = TRUE)

# Define the mixed-effects model
bid_formula <- bid ~ GLP_1_total +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request the continuous hormones predictor and covariates
hormones_partvars <- c(
  "GLP_1_total",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
GLP_1_total_analysis <- run_mixed_model_analysis(
  data = df_hi_GLP_1_final,
  formula = bid ~ GLP_1_total +
    IMC_baseline_centered +
    age_baseline_centered +
    type_chx +
    sexeF +
    (1 | id_participant),
  group_col = "id_participant",
  factor_levels = list(
    type_chx = c("1", "2", "3")
  ),
  partvars = hormones_partvars,
  partbatch = NULL,
  R2_type = "marginal",
  max_level = 1,
  emmeans_terms = NULL,
  power_terms = NULL,
  nboot = nboot,
  seed = 1234,
  show_plots = TRUE,
  parallel = TRUE,
  workers = 4
)

# Display part-R2 results
summary(
  GLP_1_total_analysis$part_r2,
  ests = TRUE,
  round_to = 3
)

# Display residual normality results from the overall analysis
GLP_1_total_analysis$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
GLP_1_total_analysis$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
GLP_1_total_analysis$vif

# Display omnibus ANOVA F-tests
GLP_1_total_analysis$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
GLP_1_total_analysis$coefficients

# Display fixed-effect confidence intervals
GLP_1_total_analysis$confidence_intervals

# Display R and package versions
GLP_1_total_analysis$reproducibility


# hormones PYY

# Load the TSV dataset
df_hi_PYY_final <- read.delim(
  "data/df_GI_bid_hi_pp_PYY_no_outliers_session.tsv",
  header = TRUE,
  sep = "\t",
  stringsAsFactors = FALSE
)

# Create IMC baseline centered variable
df_hi_PYY_final$IMC_baseline_centered <- df_hi_PYY_final$IMC_baseline - mean(df_hi_PYY_final$IMC_baseline, na.rm = TRUE)


# Create baseline age from each participant's session 1 measurement
session_one <- df_hi_PYY_final[
  as.character(df_hi_PYY_final$session) == "1" &
    !is.na(df_hi_PYY_final$age),
  c("id_participant", "age")
]

# Keep one session 1 age per participant
session_one <- session_one[
  !duplicated(session_one$id_participant),
]

# Map each participant's baseline age to all of their rows
df_hi_PYY_final$age_baseline <- session_one$age[
  match(
    df_hi_PYY_final$id_participant,
    session_one$id_participant
  )
]

# For participants without session 1 age, use their first available age
missing_baseline_age <- is.na(df_hi_PYY_final$age_baseline)

df_hi_PYY_final$age_baseline[missing_baseline_age] <- ave(
  df_hi_PYY_final$age[missing_baseline_age],
  df_hi_PYY_final$id_participant[missing_baseline_age],
  FUN = function(values) {
    available_values <- values[!is.na(values)]

    if (length(available_values) > 0) {
      available_values[1]
    } else {
      NA_real_
    }
  }
)

# Center baseline age around the sample mean
df_hi_PYY_final$age_baseline_centered <-
  df_hi_PYY_final$age_baseline -
  mean(df_hi_PYY_final$age_baseline, na.rm = TRUE)

# Verify the new variables
summary(
  df_hi_PYY_final[
    c("age", "age_baseline", "age_baseline_centered")
  ]
)

# Confirm that centered baseline age has mean approximately zero
mean(
  df_hi_PYY_final$age_baseline_centered,
  na.rm = TRUE
)

# Define the mixed-effects model
bid_formula <- bid ~ PYY +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request the continuous hormones predictor and covariates
hormones_partvars <- c(
  "PYY",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
PYY_analysis <- run_mixed_model_analysis(
  data = df_hi_PYY_final,
  formula = bid ~ PYY +
    IMC_baseline_centered +
    age_baseline_centered +
    type_chx +
    sexeF +
    (1 | id_participant),
  group_col = "id_participant",
  factor_levels = list(
    type_chx = c("1", "2", "3")
  ),
  partvars = hormones_partvars,
  partbatch = NULL,
  R2_type = "marginal",
  max_level = 1,
  emmeans_terms = NULL,
  power_terms = NULL,
  nboot = nboot,
  seed = 1234,
  show_plots = TRUE,
  parallel = TRUE,
  workers = 4
)

# Display part-R2 results
summary(
  PYY_analysis$part_r2,
  ests = TRUE,
  round_to = 3
)

# Display residual normality results from the overall analysis
PYY_analysis$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
PYY_analysis$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
PYY_analysis$vif

# Display omnibus ANOVA F-tests
PYY_analysis$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
PYY_analysis$coefficients

# Display fixed-effect confidence intervals
PYY_analysis$confidence_intervals

# Display R and package versions
PYY_analysis$reproducibility

# Define the output directory inside the Gutbrain_R project
results_dir <- "C:/Users/Patrick/Gutbrain_R/results"

# Create the directory if it does not already exist
dir.create(
  results_dir,
  showWarnings = FALSE,
  recursive = TRUE
)

# Save combined coefficient estimates, t-tests, p-values, and confidence intervals
write.table(
  hormone_coefficients,
  file = file.path(results_dir, "hormone_coefficients.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save combined partial-R2 results and bootstrap confidence intervals
write.table(
  hormone_part_r2,
  file = file.path(results_dir, "hormone_part_r2.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save the complete analysis objects for later use in R
saveRDS(
  hormone_analyses,
  file = file.path(results_dir, "hormone_analysis_objects.rds")
)

# Save the combined result tables as one R object
saveRDS(
  list(
    coefficients = hormone_coefficients,
    part_r2 = hormone_part_r2
  ),
  file = file.path(results_dir, "hormone_result_tables.rds")
)

# Confirm that the files were saved
print(list.files(results_dir, full.names = TRUE))

# Combine ANOVA tables and add the hormone identifier
hormone_anova <- do.call(
  rbind,
  lapply(names(hormone_analyses), function(hormone_name) {
    table <- as.data.frame(hormone_analyses[[hormone_name]]$anova)
    table$Term <- rownames(table)
    rownames(table) <- NULL
    table$Hormone <- hormone_name
    table
  })
)

# Combine VIF tables and add the hormone identifier
hormone_vif <- do.call(
  rbind,
  lapply(names(hormone_analyses), function(hormone_name) {
    table <- as.data.frame(hormone_analyses[[hormone_name]]$vif)
    table$Term <- rownames(table)
    rownames(table) <- NULL
    table$Hormone <- hormone_name
    table
  })
)

# Save combined ANOVA and VIF tables
write.table(
  hormone_anova,
  file = file.path(results_dir, "hormone_anova.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  hormone_vif,
  file = file.path(results_dir, "hormone_vif.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Collect the three completed hormone analyses
hormone_analyses <- list(
  Ghrelin = Ghrelin_Totale_analysis,
  GLP1 = GLP_1_total_analysis,
  PYY = PYY_analysis
)

# Extract Shapiro-Wilk test results into one data frame
hormone_shapiro <- do.call(
  rbind,
  lapply(names(hormone_analyses), function(hormone_name) {
    test_result <- hormone_analyses[[hormone_name]]$shapiro_test

    data.frame(
      Hormone = hormone_name,
      W = unname(test_result$statistic),
      P_value = test_result$p.value,
      stringsAsFactors = FALSE
    )
  })
)

# Extract Breusch-Pagan test results into one data frame
hormone_breusch_pagan <- do.call(
  rbind,
  lapply(names(hormone_analyses), function(hormone_name) {
    test_result <- hormone_analyses[[hormone_name]]$breusch_pagan_test

    data.frame(
      Hormone = hormone_name,
      BP = unname(test_result$statistic),
      DF = unname(test_result$parameter),
      P_value = test_result$p.value,
      stringsAsFactors = FALSE
    )
  })
)

# Extract standardized beta weights from each partR2 result
hormone_beta_weights <- do.call(
  rbind,
  lapply(names(hormone_analyses), function(hormone_name) {
    beta_table <- as.data.frame(
      hormone_analyses[[hormone_name]]$part_r2$BW
    )

    # Add the hormone identifier to every beta-weight row
    beta_table$Hormone <- hormone_name

    # Put the hormone name first
    beta_table[
      c("Hormone", setdiff(names(beta_table), "Hormone"))
    ]
  })
)

# Save diagnostic and standardized-effect tables as TSV files
write.table(
  hormone_shapiro,
  file = file.path(results_dir, "hormone_shapiro.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  hormone_breusch_pagan,
  file = file.path(results_dir, "hormone_breusch_pagan.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  hormone_beta_weights,
  file = file.path(results_dir, "hormone_beta_weights.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save all tables together for convenient reuse in R
saveRDS(
  list(
    shapiro = hormone_shapiro,
    breusch_pagan = hormone_breusch_pagan,
    beta_weights = hormone_beta_weights
  ),
  file = file.path(results_dir, "hormone_diagnostics_and_betas.rds")
)

# Confirm that the new files exist
list.files(
  results_dir,
  pattern = "^hormone_(shapiro|breusch_pagan|beta_weights)",
  full.names = TRUE
)

# -------------------------------------------------------------------
# Figure: GI hormone predictors plotted against bid for high-calorie foods
# -------------------------------------------------------------------

# Define hormone variables, labels, data frames, and model results
hormone_vars <- c("GLP_1_total", "PYY", "Ghrelin_Totale")
hormone_labels <- c("GLP-1", "PYY", "Total Ghrelin")
hormone_x_labels <- c(
  "GLP-1 (pmol/L)",
  "PYY (pmol/L)",
  "Total Ghrelin (pg/mL)"
)

dataframes <- list(
  df_hi_GLP_1_final,
  df_hi_PYY_final,
  df_hi_ghrelin_final
)

results_list <- list(
  GLP_1_total_analysis,
  PYY_analysis,
  Ghrelin_Totale_analysis
)

panel_labels <- c("B", "C", "D")

# Define colors per session
session_colors <- c(
  "1" = "#F2C078",
  "2" = "#F4A261",
  "3" = "#C65D3A",
  "4" = "#000000"
)

# Y-axis limits for bid
y_limits <- c(0, 5)

# Bonferroni correction threshold for 3 tests: 0.05 / 3
bonferroni_threshold <- 0.05 / 3

# Create output folder
figures_dir <- file.path(getwd(), "figures")
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

# Save the figure as a PNG
png(
  filename = file.path(figures_dir, "hormone_bid_high_calorie_panels.png"),
  width = 8,
  height = 3,
  units = "in",
  res = 300
)

# Create a 1 x 3 layout
par(mfrow = c(1, 3), mar = c(4, 4, 2, 1), oma = c(0, 0, 0, 0))

# Loop through each hormone variable
for (idx in seq_along(hormone_vars)) {
  hormone_var <- hormone_vars[idx]
  hormone_label <- hormone_labels[idx]
  x_label <- hormone_x_labels[idx]
  df_hormone <- dataframes[[idx]]
  results <- results_list[[idx]]
  panel_label <- panel_labels[idx]

  # Remove rows with missing values
  plot_data <- subset(
    df_hormone,
    !is.na(bid) &
      !is.na(get(hormone_var)) &
      !is.na(session)
  )

  if (nrow(plot_data) > 0) {
    # Determine x-axis limits based on the observed data
    x_min <- min(plot_data[[hormone_var]], na.rm = TRUE)
    x_max <- max(plot_data[[hormone_var]], na.rm = TRUE)
    x_range <- x_max - x_min
    x_limits <- c(x_min - 0.1 * x_range, x_max + 0.1 * x_range)

    # Extract regression coefficient and intercept
    beta_hormone <- results$coefficients$Estimate[
      results$coefficients$Term == hormone_var
    ]

    beta_intercept <- results$coefficients$Estimate[
      results$coefficients$Term == "(Intercept)"
    ]

    # Extract p-value
    p_value <- results$coefficients$P_value[
      results$coefficients$Term == hormone_var
    ]

    # Make the annotation for the legend
    if (is.na(p_value) || is.null(p_value)) {
      p_text <- "p=NA"
      legend_weight <- "normal"
      legend_label <- sprintf("β=%.3f, %s", beta_hormone, p_text)
    } else if (p_value < 0.001) {
      p_text <- "p<0.001"
      legend_weight <- "bold"
      legend_label <- sprintf("β=%.3f, %s", beta_hormone, p_text)
    } else {
      p_text <- sprintf("p=%.3f", p_value)
      if (p_value >= bonferroni_threshold) {
        legend_label <- sprintf("β=%.3f, %s (n.s.)", beta_hormone, p_text)
        legend_weight <- "normal"
      } else {
        legend_label <- sprintf("β=%.3f, %s", beta_hormone, p_text)
        legend_weight <- "bold"
      }
    }

    # Plot points by session
    plot(
      x = NA,
      y = NA,
      xlim = x_limits,
      ylim = y_limits,
      xlab = x_label,
      ylab = if (idx == 1) "Average Bids for\nHigh Calorie Foods ($)" else "",
      cex.lab = 0.9,
      cex.axis = 0.8,
      las = 1
    )

    for (session_value in sort(unique(plot_data$session))) {
      session_data <- subset(plot_data, session == session_value)

      points(
        x = session_data[[hormone_var]],
        y = session_data$bid,
        col = session_colors[[as.character(session_value)]],
        pch = 16,
        cex = 1.1,
        alpha = 0.6
      )
    }

    # Add model-based regression line
    x_line <- seq(x_limits[1], x_limits[2], length.out = 200)
    y_line <- beta_intercept + beta_hormone * x_line

    lines(
      x_line,
      y_line,
      col = "black",
      lwd = 2,
      lty = 2,
      alpha = 0.6
    )

    # Add the legend with significance styling
    legend(
      "topleft",
      legend = legend_label,
      bty = "n",
      text.font = if (legend_weight == "bold") 2 else 1,
      cex = 0.8
    )

    # Add panel label in the upper-right corner
    text(
      x = x_limits[2],
      y = 5,
      labels = panel_label,
      pos = 2,
      cex = 1.1,
      font = 2,
      adj = c(1, 1)
    )

    # Set exactly 5 x-axis ticks
    x_ticks <- pretty(x_limits, n = 5)
    axis(1, at = x_ticks, labels = formatC(x_ticks, format = "f", digits = 1), cex.axis = 0.8)

    # Y-axis formatting: show 2 decimal places only on the first panel
    if (idx == 1) {
      axis(
        2,
        at = seq(0, 5, by = 1),
        labels = sprintf("%.2f", seq(0, 5, by = 1)),
        cex.axis = 0.8
      )
    } else {
      axis(2, labels = FALSE, tick = FALSE)
    }

    # Remove top and right spines
    box()
  }
}

# Close the PNG device
dev.off()

cat("Saved hormone figure to:", file.path(figures_dir, "hormone_bid_high_calorie_panels.png"), "\n")
