# Load the reusable mixed-model analysis function
source("scripts/part_r2_analysis_func.R")

# Common config for all tfeq vars
nboot = 1000

# Load the TSV dataset
df_hi_calories_final <- read.delim(
  "data/df_hi_calories_final.tsv",
  header = TRUE,
  sep = "\t",
  stringsAsFactors = FALSE
)



# Define the mixed-effects model
bid_formula <- bid ~ tfeq_hungert +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request the continuous TFEQ hunger predictor and covariates
tfeq_partvars <- c(
  "tfeq_hungert",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
tfeq_hunger_analysis <- run_mixed_model_analysis(
  data = df_hi_calories_final,
  formula = bid ~ tfeq_hungert +
    IMC_baseline_centered +
    age_baseline_centered +
    type_chx +
    sexeF +
    (1 | id_participant),
  group_col = "id_participant",
  factor_levels = list(
    type_chx = c("1", "2", "3")
  ),
  partvars = tfeq_partvars,
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
  tfeq_hunger_analysis$part_r2,
  ests = TRUE,
  round_to = 3
)

# Display residual normality results from the overall analysis
tfeq_hunger_analysis$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
tfeq_hunger_analysis$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
tfeq_hunger_analysis$vif

# Display omnibus ANOVA F-tests
tfeq_hunger_analysis$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
tfeq_hunger_analysis$coefficients

# Display fixed-effect confidence intervals
tfeq_hunger_analysis$confidence_intervals

# Display R and package versions
tfeq_hunger_analysis$reproducibility


# TFEQ disinhibition
# Define the mixed-effects model
bid_formula <- bid ~ tfeq_dist +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request the continuous TFEQ hunger predictor and covariates
tfeq_partvars <- c(
  "tfeq_dist",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
tfeq_dist_analysis <- run_mixed_model_analysis(
  data = df_hi_calories_final,
  formula = bid ~ tfeq_dist +
    IMC_baseline_centered +
    age_baseline_centered +
    type_chx +
    sexeF +
    (1 | id_participant),
  group_col = "id_participant",
  factor_levels = list(
    type_chx = c("1", "2", "3")
  ),
  partvars = tfeq_partvars,
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
  tfeq_dist_analysis$part_r2,
  ests = TRUE,
  round_to = 3
)

# Display residual normality results from the overall analysis
tfeq_dist_analysis$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
tfeq_dist_analysis$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
tfeq_dist_analysis$vif

# Display omnibus ANOVA F-tests
tfeq_dist_analysis$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
tfeq_dist_analysis$coefficients

# Display fixed-effect confidence intervals
tfeq_dist_analysis$confidence_intervals

# Display R and package versions
tfeq_dist_analysis$reproducibility


# TFEQ restriction
# Define the mixed-effects model
bid_formula <- bid ~ tfeq_restrt +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request the continuous TFEQ hunger predictor and covariates
tfeq_partvars <- c(
  "tfeq_restrt",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
tfeq_restrt_analysis <- run_mixed_model_analysis(
  data = df_hi_calories_final,
  formula = bid ~ tfeq_restrt +
    IMC_baseline_centered +
    age_baseline_centered +
    type_chx +
    sexeF +
    (1 | id_participant),
  group_col = "id_participant",
  factor_levels = list(
    type_chx = c("1", "2", "3")
  ),
  partvars = tfeq_partvars,
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
  tfeq_restrt_analysis$part_r2,
  ests = TRUE,
  round_to = 3
)

# Display residual normality results from the overall analysis
tfeq_restrt_analysis$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
tfeq_restrt_analysis$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
tfeq_restrt_analysis$vif

# Display omnibus ANOVA F-tests
tfeq_restrt_analysis$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
tfeq_restrt_analysis$coefficients

# Display fixed-effect confidence intervals
tfeq_restrt_analysis$confidence_intervals

# Display R and package versions
tfeq_restrt_analysis$reproducibility


# Collect all three TFEQ analysis objects under clear names
tfeq_analyses <- list(
  Hunger = tfeq_hunger_analysis,
  Disinhibition = tfeq_dist_analysis,
  Restraint = tfeq_restrt_analysis
)

# Combine result tables while preserving meaningful model-term names
combine_tfeq_tables <- function(tfeq_analyses, table_name) {
  do.call(
    rbind,
    lapply(names(tfeq_analyses), function(tfeq_name) {
      result_table <- as.data.frame(
        tfeq_analyses[[tfeq_name]][[table_name]]
      )

      # Preserve existing term names in coefficient tables.
      # For ANOVA and VIF tables, use row names as the term names.
      if (!"Term" %in% names(result_table)) {
        result_table$Term <- rownames(result_table)
      }

      # Remove automatic row names after extracting terms
      rownames(result_table) <- NULL

      # Add the TFEQ measure identifier
      result_table$TFEQ <- tfeq_name

      result_table
    })
  )
}

# Combine coefficient estimates, tests, p-values, and confidence intervals
tfeq_coefficients <- combine_tfeq_tables(
  tfeq_analyses,
  "coefficients"
)

# Combine omnibus ANOVA F-tests
tfeq_anova <- combine_tfeq_tables(
  tfeq_analyses,
  "anova"
)

# Combine VIF results
tfeq_vif <- combine_tfeq_tables(
  tfeq_analyses,
  "vif"
)

# Extract and combine partial-R2 results from each partR2 object
tfeq_part_r2 <- do.call(
  rbind,
  lapply(names(tfeq_analyses), function(tfeq_name) {
    result_table <- as.data.frame(
      tfeq_analyses[[tfeq_name]]$part_r2$R2
    )

    # Add the TFEQ measure identifier
    result_table$TFEQ <- tfeq_name

    result_table
  })
)

# Put the TFEQ identifier first in each table
tfeq_coefficients <- tfeq_coefficients[
  c("TFEQ", setdiff(names(tfeq_coefficients), "TFEQ"))
]

tfeq_anova <- tfeq_anova[
  c("TFEQ", setdiff(names(tfeq_anova), "TFEQ"))
]

tfeq_vif <- tfeq_vif[
  c("TFEQ", setdiff(names(tfeq_vif), "TFEQ"))
]

tfeq_part_r2 <- tfeq_part_r2[
  c("TFEQ", setdiff(names(tfeq_part_r2), "TFEQ"))
]

# Display the combined result tables
tfeq_coefficients
tfeq_anova
tfeq_vif
tfeq_part_r2

# Define and create the results directory
results_dir <- "C:/Users/Patrick/Gutbrain_R/results"

dir.create(
  results_dir,
  showWarnings = FALSE,
  recursive = TRUE
)

# Save combined TFEQ result tables as TSV files
write.table(
  tfeq_coefficients,
  file.path(results_dir, "tfeq_coefficients.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  tfeq_anova,
  file.path(results_dir, "tfeq_anova.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  tfeq_vif,
  file.path(results_dir, "tfeq_vif.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  tfeq_part_r2,
  file.path(results_dir, "tfeq_part_r2.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save all complete TFEQ analysis objects for later reuse in R
saveRDS(
  tfeq_analyses,
  file.path(results_dir, "tfeq_analysis_objects.rds")
)

# Save all combined tables as one RDS file
saveRDS(
  list(
    coefficients = tfeq_coefficients,
    anova = tfeq_anova,
    vif = tfeq_vif,
    part_r2 = tfeq_part_r2
  ),
  file.path(results_dir, "tfeq_result_tables.rds")
)

# Confirm the saved files
list.files(
  results_dir,
  pattern = "^tfeq_",
  full.names = TRUE
)


# Extract Shapiro-Wilk normality-test results
tfeq_shapiro <- do.call(
  rbind,
  lapply(names(tfeq_analyses), function(tfeq_name) {
    test_result <- tfeq_analyses[[tfeq_name]]$shapiro_test

    data.frame(
      TFEQ = tfeq_name,
      W = unname(test_result$statistic),
      P_value = test_result$p.value,
      stringsAsFactors = FALSE
    )
  })
)

# Extract Breusch-Pagan heteroscedasticity-test results
tfeq_breusch_pagan <- do.call(
  rbind,
  lapply(names(tfeq_analyses), function(tfeq_name) {
    test_result <- tfeq_analyses[[tfeq_name]]$breusch_pagan_test

    data.frame(
      TFEQ = tfeq_name,
      BP = unname(test_result$statistic),
      DF = unname(test_result$parameter),
      P_value = test_result$p.value,
      stringsAsFactors = FALSE
    )
  })
)

# Extract standardized beta weights from each partR2 result
tfeq_beta_weights <- do.call(
  rbind,
  lapply(names(tfeq_analyses), function(tfeq_name) {
    beta_table <- as.data.frame(
      tfeq_analyses[[tfeq_name]]$part_r2$BW
    )

    # Add the TFEQ measure identifier
    beta_table$TFEQ <- tfeq_name

    # Place the identifier in the first column
    beta_table[
      c("TFEQ", setdiff(names(beta_table), "TFEQ"))
    ]
  })
)

# Save diagnostic and standardized-beta tables
write.table(
  tfeq_shapiro,
  file.path(results_dir, "tfeq_shapiro.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  tfeq_breusch_pagan,
  file.path(results_dir, "tfeq_breusch_pagan.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  tfeq_beta_weights,
  file.path(results_dir, "tfeq_beta_weights.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save all diagnostic results and beta weights together
saveRDS(
  list(
    shapiro = tfeq_shapiro,
    breusch_pagan = tfeq_breusch_pagan,
    beta_weights = tfeq_beta_weights
  ),
  file.path(results_dir, "tfeq_diagnostics_and_betas.rds")
)

# Confirm that the new files were created
list.files(
  results_dir,
  pattern = "^tfeq_(shapiro|breusch_pagan|beta_weights)",
  full.names = TRUE
)

# -------------------------------------------------------------------
# Figure: TFEQ predictors plotted against bid for high-calorie foods
# -------------------------------------------------------------------

# Define the TFEQ variables, labels, and corresponding model results
tfeq_vars <- c("tfeq_restrt", "tfeq_dist", "tfeq_hungert")
tfeq_labels <- c("TFEQ Restraint", "TFEQ Disinhibition", "TFEQ Hunger")
x_axis_labels <- c(
  "TFEQ Total Restraint",
  "TFEQ Total Disinhibition",
  "TFEQ Total Hunger"
)
results_list <- list(
  tfeq_restrt_analysis,
  tfeq_dist_analysis,
  tfeq_hunger_analysis
)
x_limits_list <- list(c(0, 21), c(0, 16), c(-0.5, 14))
x_ticks_list <- list(
  c(0, 3, 6, 9, 12, 15, 18, 21),
  c(0, 2, 4, 6, 8, 10, 12, 14, 16),
  c(0, 2, 4, 6, 8, 10, 12, 14)
)
panel_labels <- c("E", "F", "G")

# Define colors for each session
session_colors <- c(
  "1" = "#F2C078",
  "2" = "#F4A261",
  "3" = "#C65D3A",
  "4" = "#000000"
)

# Create the output directory for figures
figures_dir <- file.path(getwd(), "figures")
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

# Open a png device to save the figure
png(
  filename = file.path(figures_dir, "tfeq_bid_high_calorie_panels.png"),
  width = 8,
  height = 3,
  units = "in",
  res = 300
)

# Create a 1 x 3 layout
par(mfrow = c(1, 3), mar = c(4, 4, 2, 1), oma = c(0, 0, 0, 0))

# Loop over each TFEQ variable
for (idx in seq_along(tfeq_vars)) {
  tfeq_var <- tfeq_vars[idx]
  tfeq_label <- tfeq_labels[idx]
  x_label <- x_axis_labels[idx]
  model_result <- results_list[[idx]]
  x_limits <- x_limits_list[[idx]]
  x_ticks <- x_ticks_list[[idx]]
  panel_label <- panel_labels[idx]

  # Keep only complete observations for the chosen variables
  plot_data <- subset(
    df_hi_calories_final,
    !is.na(bid) &
      !is.na(get(tfeq_var)) &
      !is.na(session)
  )

  if (nrow(plot_data) > 0) {
    # Extract the regression slope and intercept from the model
    beta_tfeq <- model_result$coefficients$Estimate[
      model_result$coefficients$Term == tfeq_var
    ]

    beta_intercept <- model_result$coefficients$Estimate[
      model_result$coefficients$Term == "(Intercept)"
    ]

    # Plot each session in a different color
    plot(
      x = NA,
      y = NA,
      xlim = x_limits,
      ylim = c(0, 5),
      xlab = x_label,
      ylab = if (idx == 1) "Average Bids for\nHigh Calorie Foods ($)" else "",
      xaxt = "n",
      cex.lab = 0.9,
      cex.axis = 0.8,
      las = 1
    )

    for (session_value in sort(unique(plot_data$session))) {
      session_data <- subset(plot_data, session == session_value)

      points(
        x = session_data[[tfeq_var]],
        y = session_data$bid,
        col = session_colors[[as.character(session_value)]],
        pch = 16,
        cex = 1.1,
        alpha = 0.6
      )
    }

    # Add the fitted regression line from the mixed model
    x_line <- seq(x_limits[1], x_limits[2], length.out = 200)
    y_line <- beta_intercept + beta_tfeq * x_line

    lines(
      x_line,
      y_line,
      col = "black",
      lwd = 2,
      lty = 2,
      alpha = 0.6
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

    # Add custom x ticks
    axis(1, at = x_ticks, labels = x_ticks, cex.axis = 0.8)

    # Remove top and right spines by plotting a simple box
    box()

    # Hide y-axis labels for non-first panels
    if (idx > 1) {
      axis(2, labels = FALSE, tick = FALSE)
    }
  }
}

# Finish the plot
par(mfrow = c(1, 1))
dev.off()

cat("Saved TFEQ high-calorie figure to:", file.path(figures_dir, "tfeq_bid_high_calorie_panels.png"), "\n")


