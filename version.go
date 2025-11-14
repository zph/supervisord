package main

import (
	"fmt"
)

// VERSION the version of supervisor (set via ldflags at build time)
// Example: go build -ldflags "-X main.VERSION=v1.0.0 -X main.COMMIT=abc123"

var (
	VERSION = "dev"
	COMMIT  = "unknown"
)


// VersionCommand implement the flags.Commander interface
type VersionCommand struct {
}

var versionCommand VersionCommand

// Execute implement Execute() method defined in flags.Commander interface, executes the given command
func (v VersionCommand) Execute(args []string) error {
	fmt.Println("Version:", VERSION)
	fmt.Println(" Commit:", COMMIT)
	return nil
}

func init() {
	parser.AddCommand("version",
		"show the version of supervisor",
		"display the supervisor version",
		&versionCommand)
}
