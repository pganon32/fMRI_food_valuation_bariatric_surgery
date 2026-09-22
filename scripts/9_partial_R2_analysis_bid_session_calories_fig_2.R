# Load the reusable mixed-model analysis function
source("scripts/part_r2_analysis_func.R")


# Load the TSV dataset
df_hi_n_lo_final <- read.delim(
  "data/df_hi_n_lo_final.tsv",
  header = TRUE,
  sep = "\t",
  stringsAsFactors = FALSE
)

# Set categorical variables and their reference categories
factor_levels <- list(
  session = c("1", "2", "3", "4"),
  calories = c("hi", "lo"),
  type_chx = c("1", "2", "3")
)

# Define the mixed-effects model
bid_formula <- bid ~ session * calories +
  IMC_baseline_centered +
  age_baseline_centered +
  type_chx +
  sexeF +
  (1 | id_participant)

# Request individual fixed-effect and interaction effect sizes
bid_partvars <- c(
  "session",
  "calories",
  "session:calories",
  "IMC_baseline_centered",
  "age_baseline_centered",
  "type_chx",
  "sexeF"
)

# Request overall session and calorie effects, including interactions
bid_partbatch <- list(
  session_overall = c("session", "session:calories"),
  calories_overall = c("calories", "session:calories")
)

# Estimate only the grouped overall effects
# max_level must remain NULL when partbatch is used
bid_analysis_overall <- run_mixed_model_analysis(
  data = df_hi_n_lo_final,
  formula = bid_formula,
  group_col = "id_participant",
  factor_levels = factor_levels,
  partvars = NULL,
  partbatch = bid_partbatch,
  R2_type = "marginal",
  max_level = NULL,
  emmeans_terms = "session:calories",
  power_terms = "session2:calorieslo",
  power_nsim = 10,
  nboot = 10,
  seed = 1234,
  show_plots = FALSE,
  parallel = TRUE,
  workers = 4
)

# Display the grouped effect sizes
summary(
  bid_analysis_overall$part_r2,
  ests = TRUE,
  round_to = 3
)

if (exists("bid_analysis_individual")) {
  summary(
    bid_analysis_individual$part_r2,
    ests = TRUE,
    round_to = 3
  )
}

# Display residual normality results from the overall analysis
bid_analysis_overall$shapiro_test

# Display the Breusch-Pagan heteroscedasticity test
bid_analysis_overall$breusch_pagan_test

# Display VIF/GVIF results for the fixed effects
bid_analysis_overall$vif

# Display omnibus ANOVA F-tests
bid_analysis_overall$anova

# Display coefficient estimates, t-tests, p-values, and confidence intervals
bid_analysis_overall$coefficients

# Display fixed-effect confidence intervals
bid_analysis_overall$confidence_intervals

# Display R and package versions
bid_analysis_overall$reproducibility

# Display adjusted means for the selected term
bid_analysis_overall$emmeans[["session:calories"]]

# Display pairwise Cohen's d comparisons
bid_analysis_overall$cohens_d[["session:calories"]]

# Display power for the requested coefficient
bid_analysis_overall$power[["session2:calorieslo"]]

# Create the results directory
results_dir <- "C:/Users/Patrick/Gutbrain_R/results"

dir.create(
  results_dir,
  showWarnings = FALSE,
  recursive = TRUE
)

# Collect the completed overall analysis
bid_analyses <- list(
  overall = bid_analysis_overall
)

# Add the individual analysis only if it exists
if (exists("bid_analysis_individual")) {
  bid_analyses$individual <- bid_analysis_individual
}

# Helper function for combining model result tables
combine_bid_tables <- function(analyses, table_name) {
  do.call(
    rbind,
    lapply(names(analyses), function(analysis_name) {
      result_table <- as.data.frame(
        analyses[[analysis_name]][[table_name]]
      )

      # Preserve row names as model-term names where needed
      if (!"Term" %in% names(result_table)) {
        result_table$Term <- rownames(result_table)
      }

      rownames(result_table) <- NULL
      result_table$Analysis <- analysis_name

      result_table[
        c("Analysis", setdiff(names(result_table), "Analysis"))
      ]
    })
  )
}

# Combine coefficient, ANOVA, and VIF tables
bid_coefficients <- combine_bid_tables(
  bid_analyses,
  "coefficients"
)

bid_anova <- combine_bid_tables(
  bid_analyses,
  "anova"
)

bid_vif <- combine_bid_tables(
  bid_analyses,
  "vif"
)

# Extract partial-R2 results
bid_part_r2 <- do.call(
  rbind,
  lapply(names(bid_analyses), function(analysis_name) {
    result_table <- as.data.frame(
      bid_analyses[[analysis_name]]$part_r2$R2
    )

    result_table$Analysis <- analysis_name

    result_table[
      c("Analysis", setdiff(names(result_table), "Analysis"))
    ]
  })
)

# Extract standardized beta weights when available
bid_beta_weights <- do.call(
  rbind,
  lapply(names(bid_analyses), function(analysis_name) {
    beta_table <- as.data.frame(
      bid_analyses[[analysis_name]]$part_r2$BW
    )

    beta_table$Analysis <- analysis_name

    beta_table[
      c("Analysis", setdiff(names(beta_table), "Analysis"))
    ]
  })
)

# Extract Shapiro-Wilk test results
bid_shapiro <- do.call(
  rbind,
  lapply(names(bid_analyses), function(analysis_name) {
    test_result <- bid_analyses[[analysis_name]]$shapiro_test

    data.frame(
      Analysis = analysis_name,
      W = unname(test_result$statistic),
      P_value = test_result$p.value,
      stringsAsFactors = FALSE
    )
  })
)

# Extract Breusch-Pagan test results
bid_breusch_pagan <- do.call(
  rbind,
  lapply(names(bid_analyses), function(analysis_name) {
    test_result <- bid_analyses[[analysis_name]]$breusch_pagan_test

    data.frame(
      Analysis = analysis_name,
      BP = unname(test_result$statistic),
      DF = unname(test_result$parameter),
      P_value = test_result$p.value,
      stringsAsFactors = FALSE
    )
  })
)

# Extract adjusted means, Cohen's d, and power results
bid_emmeans <- bid_analysis_overall$emmeans[["session:calories"]]
bid_cohens_d <- bid_analysis_overall$cohens_d[["session:calories"]]
bid_power <- bid_analysis_overall$power[["session2:calorieslo"]]

# Save tabular results as TSV files
write.table(
  bid_coefficients,
  file.path(results_dir, "bid_session_calories_coefficients.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  bid_anova,
  file.path(results_dir, "bid_session_calories_anova.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  bid_vif,
  file.path(results_dir, "bid_session_calories_vif.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  bid_part_r2,
  file.path(results_dir, "bid_session_calories_part_r2.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  bid_beta_weights,
  file.path(results_dir, "bid_session_calories_beta_weights.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  bid_shapiro,
  file.path(results_dir, "bid_session_calories_shapiro.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.table(
  bid_breusch_pagan,
  file.path(results_dir, "bid_session_calories_breusch_pagan.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save EMMs, Cohen's d, and power as RDS files
saveRDS(
  bid_emmeans,
  file.path(results_dir, "bid_session_calories_emmeans.rds")
)

saveRDS(
  bid_cohens_d,
  file.path(results_dir, "bid_session_calories_cohens_d.rds")
)

saveRDS(
  bid_power,
  file.path(results_dir, "bid_session_calories_power.rds")
)

# Save complete analysis objects
saveRDS(
  bid_analyses,
  file.path(results_dir, "bid_session_calories_analysis_objects.rds")
)

# Save all result tables and additional results together
saveRDS(
  list(
    coefficients = bid_coefficients,
    anova = bid_anova,
    vif = bid_vif,
    part_r2 = bid_part_r2,
    beta_weights = bid_beta_weights,
    shapiro = bid_shapiro,
    breusch_pagan = bid_breusch_pagan,
    emmeans = bid_emmeans,
    cohens_d = bid_cohens_d,
    power = bid_power
  ),
  file.path(results_dir, "bid_session_calories_result_tables.rds")
)

# Confirm that the files were created
list.files(
  results_dir,
  pattern = "^bid_session_calories_",
  full.names = TRUE
)

# Convert EMMs and Cohen's d results to data frames
bid_emmeans_tsv <- as.data.frame(bid_emmeans)
bid_cohens_d_tsv <- as.data.frame(bid_cohens_d)

# Save EMMs as TSV
write.table(
  bid_emmeans_tsv,
  file.path(results_dir, "bid_session_calories_emmeans.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Save Cohen's d comparisons as TSV
write.table(
  bid_cohens_d_tsv,
  file.path(results_dir, "bid_session_calories_cohens_d.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# Calculate the mean and SEM of bid for each session where calories = "hi"
mean_bid_high_per_session <- aggregate(
  bid ~ session,
  data = subset(df_hi_n_lo_final, calories == "hi"),
  FUN = mean
)

sem_bid_high_per_session <- aggregate(
  bid ~ session,
  data = subset(df_hi_n_lo_final, calories == "hi"),
  FUN = function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))
)

# Calculate the mean and SEM of bid for each session where calories = "lo"
mean_bid_low_per_session <- aggregate(
  bid ~ session,
  data = subset(df_hi_n_lo_final, calories == "lo"),
  FUN = mean
)

sem_bid_low_per_session <- aggregate(
  bid ~ session,
  data = subset(df_hi_n_lo_final, calories == "lo"),
  FUN = function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))
)

# Define the sessions
sessions <- c("Pre-surgery", "4 months", "12 months", "24 months")
x <- seq_along(sessions)

# Extract means and SEMs by session number 1:4
mean_bid_low <- sapply(1:4, function(i) {
  row <- mean_bid_low_per_session[mean_bid_low_per_session$session == as.character(i), ]
  if (nrow(row) == 0) 0 else row$bid
})

sem_bid_low <- sapply(1:4, function(i) {
  row <- sem_bid_low_per_session[sem_bid_low_per_session$session == as.character(i), ]
  if (nrow(row) == 0) 0 else row$bid
})

mean_bid_high <- sapply(1:4, function(i) {
  row <- mean_bid_high_per_session[mean_bid_high_per_session$session == as.character(i), ]
  if (nrow(row) == 0) 0 else row$bid
})

sem_bid_high <- sapply(1:4, function(i) {
  row <- sem_bid_high_per_session[sem_bid_high_per_session$session == as.character(i), ]
  if (nrow(row) == 0) 0 else row$bid
})

# Save the figure to the project figures folder
figures_dir <- file.path(getwd(), "figures")
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

png(
  filename = file.path(figures_dir, "bid_session_calories_plot.png"),
  width = 8,
  height = 6,
  units = "in",
  res = 300
)

# Plot the data
plot(
  x,
  mean_bid_low,
  type = "o",
  pch = 16,
  col = "blue",
  lwd = 4,
  cex = 1.5,
  ylim = c(0, 5),
  xaxt = "n",
  xlab = "",
  ylab = "Average bids ($)",
  main = "",
  cex.lab = 1.2,
  cex.axis = 1.2,
  lty = 1,
  frame.plot = FALSE
)

arrows(
  x,
  mean_bid_low - sem_bid_low,
  x,
  mean_bid_low + sem_bid_low,
  angle = 90,
  code = 3,
  length = 0.08,
  col = "blue",
  lwd = 2
)

lines(
  x,
  mean_bid_high,
  type = "o",
  pch = 16,
  col = "orange",
  lwd = 4,
  cex = 1.5
)

arrows(
  x,
  mean_bid_high - sem_bid_high,
  x,
  mean_bid_high + sem_bid_high,
  angle = 90,
  code = 3,
  length = 0.08,
  col = "orange",
  lwd = 2
)

axis(
  1,
  at = x,
  labels = sessions,
  cex.axis = 1.1
)

legend(
  "topright",
  legend = c("Low Caloric Density", "High Caloric Density"),
  col = c("blue", "orange"),
  lwd = 4,
  pch = 16,
  bty = "n",
  cex = 1.1
)

grid(NULL)

dev.off()
