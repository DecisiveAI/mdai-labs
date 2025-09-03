package main

import (
	"fmt"
	"time"
)

func main() {
	// Get the current time in UTC
	now := time.Now().UTC()

	// Truncate to the start of the current hour
	currentHourStart := now.Truncate(time.Hour)

	// Calculate the start of the previous hour
	previousHourStart := currentHourStart.Add(-1 * time.Hour)

	// Convert both to Unix milliseconds
	startMs := previousHourStart.UnixMilli()
	endMs := currentHourStart.UnixMilli()

	// Build the URL
	url := fmt.Sprintf(
		"http://localhost:4400/logs/hub-monitor-audit-logs/files?start=%d&end=%d",
		startMs, endMs,
	)

	fmt.Println(url)
}
