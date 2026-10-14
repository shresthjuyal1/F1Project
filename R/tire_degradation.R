# =============================================================================
# Modelling Tyre Degradation in Formula 1 with Linear Regression
# -----------------------------------------------------------------------------
# Race   : 2011 Australian Grand Prix (Albert Park), Lewis Hamilton, 58 laps
# Model  : lap_time_ms = b0 + b1 * lap + error, fitted separately per stint
#          b1 = estimated lap-time loss per lap (ms/lap), i.e. degradation rate
# Data   : data/ (lap times from the Kaggle "Formula 1 Race Data" lapTimes.csv)
#
# Run from the repository root:  Rscript R/tire_degradation.R
# =============================================================================

library(readxl)
library(ggplot2)

dir.create("figures", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Load data
# -----------------------------------------------------------------------------
full_race <- read_excel("data/hamilton_full_race.xlsx")

stints <- lapply(1:3, function(i) {
  read_excel(sprintf("data/hamilton_stint%d.xlsx", i))[, c("lap", "milliseconds")]
})

test_stints <- lapply(1:3, function(i) {
  read_excel(sprintf("data/test_driver_stint%d.xlsx", i))[, c("lap", "milliseconds")]
})

# -----------------------------------------------------------------------------
# 2. Exploratory plot of the whole race
#    Three separate upward trends correspond to three sets of tyres; the
#    jumps at laps 16 and 36 are pit stops.
# -----------------------------------------------------------------------------
race_plot <- ggplot(full_race, aes(x = lap, y = milliseconds)) +
  geom_point() +
  geom_vline(xintercept = c(16, 36), linetype = "dashed", colour = "grey50") +
  labs(title = "Hamilton lap times, 2011 Australian GP",
       x = "Lap number", y = "Lap time (ms)") +
  theme_minimal()
ggsave("figures/race_lap_times.png", race_plot, width = 7, height = 4.5, dpi = 150)

# -----------------------------------------------------------------------------
# 3. Fit one simple linear regression per stint
# -----------------------------------------------------------------------------
models <- lapply(stints, function(d) lm(milliseconds ~ lap, data = d))

for (i in seq_along(models)) {
  cat(sprintf("\n===== Stint %d (laps %d-%d) =====\n",
              i, min(stints[[i]]$lap), max(stints[[i]]$lap)))
  print(summary(models[[i]]))
}

summary_table <- do.call(rbind, lapply(seq_along(models), function(i) {
  s <- summary(models[[i]])
  data.frame(
    stint        = i,
    laps         = paste(range(stints[[i]]$lap), collapse = "-"),
    n            = nrow(stints[[i]]),
    intercept    = round(coef(models[[i]])[1], 2),
    slope_ms_lap = round(coef(models[[i]])[2], 2),
    slope_se     = round(s$coefficients[2, 2], 2),
    p_value      = signif(s$coefficients[2, 4], 3),
    r_squared    = round(s$r.squared, 4),
    adj_r2       = round(s$adj.r.squared, 4)
  )
}))
print(summary_table, row.names = FALSE)

# -----------------------------------------------------------------------------
# 4. Residual diagnostics (linearity, constant variance, normality)
# -----------------------------------------------------------------------------
png("figures/residual_diagnostics.png", width = 1500, height = 1200, res = 150)
par(mfrow = c(3, 3), mar = c(4, 4, 2, 1))
for (i in seq_along(models)) {
  m <- models[[i]]
  plot(fitted(m), resid(m), main = sprintf("Stint %d: residuals vs fitted", i),
       xlab = "Fitted (ms)", ylab = "Residual (ms)")
  abline(h = 0, lty = 2)
  plot(stints[[i]]$lap, resid(m), main = sprintf("Stint %d: residuals vs lap", i),
       xlab = "Lap", ylab = "Residual (ms)")
  abline(h = 0, lty = 2)
  qqnorm(resid(m), main = sprintf("Stint %d: normal Q-Q", i))
  qqline(resid(m))
}
dev.off()

# -----------------------------------------------------------------------------
# 5. Sensitivity: refit without the anomalous laps identified in the report
#    (lap 32: Hamilton ran wide; lap 40: lapped traffic; lap 58: final lap)
# -----------------------------------------------------------------------------
drop_laps <- c(32, 40, 58)
robust <- sapply(stints, function(d) {
  coef(lm(milliseconds ~ lap, data = d[!(d$lap %in% drop_laps), ]))[2]
})
cat("\nSlope without anomalous laps (ms/lap):", round(robust, 1), "\n")

# -----------------------------------------------------------------------------
# 6. Out-of-sample check: predict a second driver's first stint with the
#    stint-1 model (lap 1 excluded: standing start)
# -----------------------------------------------------------------------------
test <- test_stints[[1]][test_stints[[1]]$lap >= 2, ]
pred <- predict(models[[1]], newdata = test)
err  <- test$milliseconds - pred
cat(sprintf("\nTest-set MAE: %.0f ms, RMSE: %.0f ms\n", mean(abs(err)), sqrt(mean(err^2))))
