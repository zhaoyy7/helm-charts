// Copyright 2022 SAP SE
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/Masterminds/semver/v3"
	"gopkg.in/yaml.v2"
)

type chartData struct {
	Path         string `yaml:"-"`
	Name         string `yaml:"name"`
	Version      string `yaml:"version"`
	Dependencies []any  `yaml:"dependencies"`
}

func main() {
	var (
		major bool
		minor bool
		patch bool
	)
	flag.BoolVar(&major, "major", false, "Bump a chart's MAJOR version. Use this when you make incompatible API changes.")
	flag.BoolVar(&minor, "minor", false, "Bump a chart's MINOR version. Use this when you add functionality in a backwards compatible manner.")
	flag.BoolVar(&patch, "patch", true, "Bump a chart's PATCH version. Use this when you make backwards compatible bug fixes.")
	flag.Parse()

	args := flag.Args()
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, "usage: bump-chart-version [OPTIONS] <paths-to-chart-directories>...")
		os.Exit(1)
	}

	for _, v := range args {
		dirPath := strings.TrimSpace(v)
		filename := filepath.Join(dirPath, "Chart.yaml")
		b, err := os.ReadFile(filename)
		must(err)
		chart := chartData{Path: dirPath}
		must(yaml.Unmarshal(b, &chart))

		oldVer, err := semver.NewVersion(chart.Version)
		must(err)

		var newVer semver.Version
		switch {
		case major:
			newVer = oldVer.IncMajor()
		case minor:
			newVer = oldVer.IncMinor()
		default:
			newVer = oldVer.IncPatch()
		}

		rx, err := regexp.Compile(fmt.Sprintf(`version: ("|')?%s("|')?`, oldVer.String()))
		must(err)
		match := rx.Find(b)
		if match == nil {
			must(errors.New("could not find version in Chart.yaml using Regex"))
		}

		b = bytes.Replace(b, match, []byte("version: "+newVer.String()), 1)
		must(os.WriteFile(filename, b, 0o644))

		fmt.Printf("==> %s: %s -> %s\n", chart.Path, oldVer.String(), newVer.String())

		if len(chart.Dependencies) > 0 {
			cmd := exec.Command("helm", "dependency", "update")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			absPath, err := filepath.Abs(dirPath)
			must(err)
			cmd.Dir = absPath
			must(cmd.Run())
		}
	}
}

func must(err error) {
	if err != nil {
		panic(err.Error())
	}
}
