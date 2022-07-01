#!/usr/bin/env bash
set -ex
trap "{{ include "utils.proxysql.proxysql_signal_stop_script" . }}" EXIT

designate-manage database sync
