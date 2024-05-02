ggplot(trainingset, aes(x = lap, y = milliseconds)) +
  +     geom_point() +
  +     labs(x = "lap number", y = "laptime (milliseconds)") +
  +     ggtitle("Laptime vs Lap number") +
  +     ylim(90000, 94700)

