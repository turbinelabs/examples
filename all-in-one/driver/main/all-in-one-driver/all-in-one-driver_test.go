package main

import (
	"testing"

	"github.com/turbinelabs/test/assert"
)

func TestCLI(t *testing.T) {
	assert.Nil(t, mkCLI().Validate())
}
