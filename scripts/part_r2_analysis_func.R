# Install missing packages once before running the analysis
required_packages <- c(
  "partR2",
  "lme4",
  "lmerTest",
  "lmtest",
  "car",
  "future",
  "furrr",
  "emmeans",
  "simr"
)


missing_packages <- required_packages[
  !required_packages %in% rownames(installed.packages())
]

if (length(missing_packages) > 0) {
  install.packages(
    missing_packages,
    repos = "https://cloud.r-project.org"
  )
}

# Load packages required for mixed models, diagnostics, and R-squared estimates
library(partR2)
library(lme4)
library(lmerTest)
library(lmtest)
library(car)
library(future)
library(furrr)
library(emmeans)
library(simr)

# power sim not working as of 2026-08-28

# Reproducible mixed-model analysis function
run_mixed_model_analysis <- function(
    data,
    formula,
    group_col = "id_participant",
    factor_levels = list(),
    partvars = NULL,
    partbatch = NULL,
    R2_type = "marginal",
    max_level = 1,
    nboot = 100,
    seed = 1234,
    show_plots = TRUE,
    parallel = FALSE,
    workers = 2,
    emmeans_terms = NULL,
    power_terms = NULL,
    power_nsim = 1000,
    power_progress = TRUE
) {
  # Check that the grouping column exists
  if (!group_col %in% names(data)) {
    stop("Grouping column not found: ", group_col)
  }

  # Apply requested factor levels, including reference-category ordering
  for (column_name in names(factor_levels)) {
    if (!column_name %in% names(data)) {
      stop("Factor column not found: ", column_name)
    }

    data[[column_name]] <- factor(
      data[[column_name]],
      levels = factor_levels[[column_name]]
    )
  }

  # Ensure the participant identifier is categorical
  data[[group_col]] <- factor(data[[group_col]])

 # Remove the random-effects terms to identify the fixed-effect variables
  fixed_formula <- lme4::nobars(formula)

  # Build the fixed-effect model frame without silently dropping rows
  fixed_model_frame <- model.frame(
    fixed_formula,
    data = data,
    na.action = na.pass
  )

  # Keep rows complete for every model variable and the grouping variable
  complete_rows <- complete.cases(
    fixed_model_frame,
    data[[group_col]]
  )

  # Use one stable dataset for the model and every partR2 refit
  model_input_data <- data[
    complete_rows,
    ,
    drop = FALSE
  ]

  # Ensure the grouping variable is categorical
  model_input_data[[group_col]] <- factor(
    model_input_data[[group_col]]
  )

  # Fit the model using the pre-filtered data
  model <- lmerTest::lmer(
    formula = formula,
    data = model_input_data,
    REML = TRUE,
    na.action = na.exclude
  )

  # Extract the exact fitted-model data
  model_data <- model.frame(model)

  # Remove the NA bookkeeping attribute before passing data to partR2
  attr(model_data, "na.action") <- NULL

  # Confirm that the model and data have identical row counts
  if (nrow(model_data) != nobs(model)) {
    stop(
      "Model/data row mismatch: ",
      nrow(model_data),
      " rows versus ",
      nobs(model),
      " observations."
    )
  }

    # Extract fixed-effect term labels from the model formula
  fixed_term_labels <- attr(
    terms(lme4::nobars(formula)),
    "term.labels"
  )

  # Select requested terms by number, for example emmeans_terms = 1,
  # or by name, for example emmeans_terms = "session"
  if (is.null(emmeans_terms)) {
    emmeans_terms <- integer(0)
  }

  if (is.numeric(emmeans_terms)) {
    selected_emmeans_terms <- fixed_term_labels[emmeans_terms]
  } else {
    selected_emmeans_terms <- emmeans_terms
  }

  # Check that all requested terms exist in the model
  unknown_terms <- setdiff(
    selected_emmeans_terms,
    fixed_term_labels
  )

  if (length(unknown_terms) > 0) {
    stop(
      "Unknown emmeans term(s): ",
      paste(unknown_terms, collapse = ", "),
      "\nAvailable terms: ",
      paste(fixed_term_labels, collapse = ", ")
    )
  }

   # Store estimated marginal means and Cohen's d results by model term
  emmeans_results <- list()
  cohens_d_results <- list()

  # Calculate results only when terms were requested
  if (length(selected_emmeans_terms) > 0) {
    for (term_label in selected_emmeans_terms) {
      # Estimate adjusted marginal means for the selected term
      estimated_means <- emmeans::emmeans(
        model,
        specs = as.formula(paste("~", term_label))
      )

      # Create direct pairwise comparisons between estimated marginal means
    pairwise_contrasts <- emmeans::contrast(
        estimated_means,
        method = "pairwise",
        adjust = "tukey"
    )

      # Convert the already-created direct contrasts to Cohen's d
    pairwise_d <- emmeans::eff_size(
        pairwise_contrasts,
        sigma = sigma(model),
        edf = df.residual(model),
        method = "identity"
    )

      # Store the marginal means and direct Cohen's d comparisons
      emmeans_results[[term_label]] <- estimated_means
      cohens_d_results[[term_label]] <- pairwise_d
    }
  }

  # Calculate omnibus F-tests using Satterthwaite degrees of freedom
  anova_results <- anova(
    model,
    ddf = "Satterthwaite"
  )
    

  # Extract coefficient estimates, t-tests, standard errors, and p-values
  coefficient_results <- as.data.frame(
    coef(summary(model))
  )

  # Preserve coefficient names as an explicit column
  coefficient_results$Term <- rownames(coefficient_results)
  rownames(coefficient_results) <- NULL

  # Rename columns for easier interpretation
  names(coefficient_results) <- c(
    "Estimate",
    "Std_Error",
    "DF",
    "T_value",
    "P_value",
    "Term"
  )

  # Calculate 95% Wald confidence intervals for fixed effects only
  confidence_intervals <- as.data.frame(
    confint(
      model,
      parm = "beta_",
      method = "Wald"
    )
  )

  # Preserve term names for merging with coefficient results
  confidence_intervals$Term <- rownames(confidence_intervals)
  rownames(confidence_intervals) <- NULL

  # Rename confidence-interval columns
  names(confidence_intervals) <- c(
    "CI_lower",
    "CI_upper",
    "Term"
  )

  # Combine coefficient tests and confidence intervals into one table
  coefficient_results <- merge(
    coefficient_results,
    confidence_intervals,
    by = "Term",
    sort = FALSE
  )

  # Extract the exact rows used by the fitted model
  model_data <- model.frame(model)

  # Extract model residuals and fitted values
  model_residuals <- residuals(model)
  model_fitted <- fitted(model)

  # Store residuals and fitted values for later inspection
  diagnostic_data <- data.frame(
    fitted = model_fitted,
    residuals = model_residuals
  )

  # Test residual normality when the Shapiro-Wilk sample-size limit allows it
  if (length(model_residuals) <= 5000) {
    shapiro_result <- shapiro.test(model_residuals)
  } else {
    shapiro_result <- "Shapiro-Wilk test skipped because n > 5000"
  }

  # Approximate heteroscedasticity test based on squared residuals
  variance_model <- lm(
    I(residuals^2) ~ fitted,
    data = diagnostic_data
  )

  breusch_pagan_result <- lmtest::bptest(variance_model)

  # Remove the random-effects portion before calculating fixed-effect VIFs
  fixed_formula <- lme4::nobars(formula)

  fixed_effect_model <- lm(
    formula = fixed_formula,
    data = model_data,
    na.action = na.omit
  )

  # Calculate predictor-level VIFs for models containing interactions
  vif_results <- car::vif(
    fixed_effect_model,
    type = "predictor"
  )

  # Produce standard residual diagnostic plots when requested
  if (show_plots) {
    old_plot_settings <- par(no.readonly = TRUE)
    on.exit(par(old_plot_settings), add = TRUE)

    par(mfrow = c(2, 2))

    # Residuals versus fitted values
    plot(
      model_fitted,
      model_residuals,
      xlab = "Fitted values",
      ylab = "Residuals",
      main = "Residuals vs Fitted Values",
      pch = 19,
      col = "steelblue"
    )
    abline(h = 0, lty = 2, col = "red")

    # Normal Q-Q plot
    qqnorm(
      model_residuals,
      main = "Normal Q-Q Plot",
      pch = 19,
      col = "steelblue"
    )
    qqline(model_residuals, col = "red", lwd = 2)

    # Scale-location plot
    plot(
      model_fitted,
      sqrt(abs(scale(model_residuals))),
      xlab = "Fitted values",
      ylab = "Sqrt(|Standardized residuals|)",
      main = "Scale-Location Plot",
      pch = 19,
      col = "steelblue"
    )

    # Histogram of residuals
    hist(
      model_residuals,
      breaks = 20,
      main = "Histogram of Residuals",
      xlab = "Residuals",
      col = "lightsteelblue",
      border = "white"
    )
  }

  # Set a seed so parametric bootstrap results are reproducible
  set.seed(seed)

    # Store the part-R2 result only once
  part_r2_result <- NULL

  # Configure parallel processing for partR2 bootstrapping
  if (parallel && (!is.null(partvars) || !is.null(partbatch))) {
    previous_plan <- future::plan()
    on.exit(future::plan(previous_plan), add = TRUE)

    future::plan(
      future::multisession,
      workers = workers
    )
  }

  if (!is.null(partvars) || !is.null(partbatch)) {
    # Extract exactly the rows used by the fitted model
    model_data <- model.frame(model)

    # Verify that the data and model have identical observation counts
    if (nrow(model_data) != nobs(model)) {
      stop("Model/data row mismatch: ", nrow(model_data), " vs ", nobs(model))
    }

    # Build the partR2 arguments
    part_r2_arguments <- list(
      mod = model,
      data = model_data,
      R2_type = R2_type,
      nboot = nboot,
      parallel = parallel
    )

    # Add individual terms when requested
    if (!is.null(partvars)) {
      part_r2_arguments$partvars <- partvars
    }

    # Add grouped terms when requested
    if (!is.null(partbatch)) {
      part_r2_arguments$partbatch <- partbatch
    }

    # max_level cannot be used with partbatch
    if (!is.null(max_level) && is.null(partbatch)) {
      part_r2_arguments$max_level <- max_level
    }

    # Run partR2 once
    part_r2_result <- do.call(
      partR2::partR2,
      part_r2_arguments
    )
  }

  
    # Store post-hoc power results for requested model terms
  power_results <- list()
  power_term_mapping <- list()

  # Run power simulations only when terms have been requested
  if (!is.null(power_terms)) {
    # Get fixed-effect coefficient names from the fitted model
    fixed_effect_names <- names(lme4::fixef(model))

    # Get formula-term labels without the random-effects component
    fixed_terms <- terms(lme4::nobars(formula))
    formula_term_labels <- attr(fixed_terms, "term.labels")

    # Map model-matrix columns to their originating formula terms
    fixed_model_matrix <- model.matrix(model)
    term_assignment <- attr(fixed_model_matrix, "assign")

    # Resolve requested numeric positions or character names
    requested_terms <- power_terms

    for (requested_term in requested_terms) {
      if (is.numeric(requested_term)) {
        # Numeric values refer to formula-term positions, excluding the intercept
        if (
          requested_term < 1 ||
          requested_term > length(formula_term_labels)
        ) {
          stop(
            "Invalid power term position: ",
            requested_term,
            ". Available positions are 1 to ",
            length(formula_term_labels),
            "."
          )
        }

        formula_term <- formula_term_labels[requested_term]
        term_index <- requested_term
      } else {
        # Character values can refer to formula terms or exact coefficients
        formula_term <- as.character(requested_term)

        if (formula_term %in% formula_term_labels) {
          term_index <- match(formula_term, formula_term_labels)
        } else if (formula_term %in% fixed_effect_names) {
          term_index <- NA_integer_
        } else {
          stop(
            "Unknown power term: ",
            formula_term,
            "\nAvailable formula terms: ",
            paste(formula_term_labels, collapse = ", "),
            "\nAvailable coefficients: ",
            paste(fixed_effect_names, collapse = ", ")
          )
        }
      }

      # Select coefficients belonging to the requested formula term
      if (!is.na(term_index)) {
        term_coefficients <- colnames(fixed_model_matrix)[
          term_assignment == term_index
        ]

        # Keep only coefficients retained in the fitted model
        term_coefficients <- term_coefficients[
          term_coefficients %in% fixed_effect_names
        ]
      } else {
        # An exact coefficient name identifies one coefficient directly
        term_coefficients <- formula_term
      }

      power_term_mapping[[formula_term]] <- term_coefficients

      # Simulate power separately for every coefficient in the term
      for (coefficient_name in term_coefficients) {
        # Set a reproducible seed for this coefficient's simulations
        coefficient_seed <- seed + match(
          coefficient_name,
          fixed_effect_names
        )

        power_results[[coefficient_name]] <- simr::powerSim(
          model,
          test = simr::fixed(
            coefficient_name,
            method = "t"
          ),
          nsim = power_nsim,
          seed = coefficient_seed,
          progress = power_progress
        )
      }
    }
  }

  # Capture R and package versions for reproducibility
  package_versions <- sapply(
    required_packages,
    function(package_name) {
      as.character(packageVersion(package_name))
    }
  )

  reproducibility_info <- list(
    R_version = R.version.string,
    platform = R.version$platform,
    package_versions = package_versions,
    session_info = capture.output(sessionInfo()),
    random_seed = seed
  )

  # Return all model results, diagnostics, effect sizes, and reproducibility details
  return(list(
    model = model,
    model_data = model_data,
    anova = anova_results,
    coefficients = coefficient_results,
    confidence_intervals = confidence_intervals,
    residuals = model_residuals,
    fitted_values = model_fitted,
    shapiro_test = shapiro_result,
    breusch_pagan_test = breusch_pagan_result,
    vif = vif_results,
    part_r2 = part_r2_result,
    emmeans = emmeans_results,
    cohens_d = cohens_d_results,
    reproducibility = reproducibility_info,
    power = power_results,
    power_term_mapping = power_term_mapping
  ))
}