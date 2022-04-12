# bump-chart-version

`bump-chart-version` is a tool that can be used to bump a chart's version as per [semantic
versioning][semver]. `bump-chart-version` will also take care of updating the helm dependencies, i.e. running `helm dependency update`.

## Why?

Because it gets tedious when you have to bump multiple charts. See example below.

## Installation

```sh
go install github.com/sapcc/helm-charts/tools/bump-chart-version@latest
```

## Usage

```sh
bump-chart-version [OPTIONS] <paths-to-chart-directories>...
```

**Note**: make sure to double-check the output with `git diff` before committing any
changes.

### Options

```sh
bump-chart-version --help
```

### Example

To bump all charts that have the absent-metrics-operator enabled:

```ShellSession
$ for l in $(rg --files-with-matches 'condition: absent-metrics-operator.enabled'); do bump-chart-version "$(dirname $l)"; done
==> system/kube-monitoring-admin-k3s: 3.0.8 -> 3.0.9
==> system/kube-monitoring-metal: 4.1.0 -> 4.1.1
==> system/kube-monitoring-virtual: 2.0.8 -> 2.0.9
==> system/kube-monitoring-kubernikus: 5.0.8 -> 5.0.9
==> system/kube-monitoring-scaleout: 2.0.8 -> 2.0.9
```

[semver]: https://semver.org/spec/v2.0.0.html#summary
