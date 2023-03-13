#!/bin/bash

function process_config {

  mkdir /var/lib/plutono/etc
  cp /grafana-etc/grafana.ini /var/lib/plutono/etc/plutono.ini
  cp /grafana-etc/ldap.toml /var/lib/plutono/etc/ldap.toml

}

function start_application {

  # Set cluster region
  export CLUSTER_REGION={{.Values.global.region}}
  # Set Grafana admin/local username & password
  export PL_SECURITY_ADMIN_USER={{.Values.grafana.admin.user}}
  export PL_SECURITY_ADMIN_PASSWORD={{.Values.grafana.admin.password}}
  export GRAFANA_LOCAL_USER={{.Values.grafana.local.user}}
  export GRAFANA_LOCAL_PASSWORD={{.Values.grafana.local.password}}
  # install some plugins
  # plutono-cli plugins install grafana-piechart-panel 1.6.2
  # plutono-cli plugins install flant-statusmap-panel 0.4.2
  # plutono-cli plugins install natel-discrete-panel 0.1.1
  # plutono-cli plugins install vonage-status-panel 1.0.11
  # plutono-cli plugins install blackmirror1-statusbygroup-panel 1.1.2
  # plutono-cli plugins install digrich-bubblechart-panel 1.2.0
  # plutono-cli plugins install briangann-datatable-panel 1.0.3
  # plutono-cli plugins install grafana-worldmap-panel 0.3.3
  # plutono-cli plugins install yesoreyeram-boomtable-panel 1.4.1
  # plutono-cli plugins install jdbranham-diagram-panel 1.7.3
  # plutono-cli plugins install agenty-flowcharting-panel 0.9.1
  # plutono-cli plugins install marcusolsson-json-datasource 1.3.2
  # install sapcc/grafana-prometheus-alertmanager-datasource
  # plutono-cli --pluginUrl https://github.com/sapcc/grafana-prometheus-alertmanager-datasource/archive/master.zip plugins install prometheus-alertmanager
  # install sapcc/Grafana_Status_panel
  # plutono-cli --pluginUrl https://github.com/sapcc/Grafana_Status_panel/archive/master.zip plugins install cc-status-panel
  wget -nv https://grafana.com/api/plugins/grafana-piechart-panel/versions/latest/download -O /tmp/grafana-piechart-panel.zip
  (cd /var/lib/plutono/plugins; unzip /tmp/grafana-piechart-panel.zip; rm -f /tmp/grafana-piechart-panel.zip)

  wget -q -O /tmp/grafana_prometheus_alertmanager_datasource.zip https://github.com/sapcc/grafana-prometheus-alertmanager-datasource/archive/master.zip
  (cd /var/lib/plutono/plugins; unzip /tmp/grafana_prometheus_alertmanager_datasource.zip; rm -f /tmp/grafana_prometheus_alertmanager_datasource.zip)

  wget -q -O /tmp/grafana_status_panel.zip https://github.com/sapcc/Grafana_Status_panel/archive/master.zip
  (cd /var/lib/plutono/plugins; unzip /tmp/grafana_status_panel.zip; rm -f /tmp/grafana_status_panel.zip)

  # setup the datasources and dashboards if the setup script exists
  # wait a moment until grafana is up and write to stdout and logfile in parallel
  if [ -f /grafana-bin/grafana-initial-setup ]; then
    (while ! wget -q -O /dev/null http://localhost:3000; do sleep 5; done; bash /grafana-bin/grafana-initial-setup ) 2>&1 | tee /var/log/plutono/initial-setup.log &
  fi
  while [ ! -d /git/grafana-content/datasources-config ]; do
    echo "waiting 5 more seconds for the grafana-content to be mounted and synced via git-sync ..."
    sleep 5
  done
  # create an auto provisioning dir for grafana and copy the content from the git to it
  # the cp is required in order to be able to modify the datasources below, the dashboard
  # config references back to the dashboard-sources dir in the git repo directly
  mkdir -p /var/lib/plutono/provisioning
  # do not do the above if the are in author more - then we do not provision anything
  if [ "{{.Values.grafana.mode}}" != "author" ]; then
    rm -rf /var/lib/plutono/provisioning/dashboards
    cp -r /git/grafana-content/dashboards-config-{{.Values.grafana.mode}} /var/lib/plutono/provisioning/dashboards
  fi
  rm -rf /var/lib/plutono/provisioning/datasources
  mkdir -p /var/lib/plutono/provisioning/datasources
  cd /git/grafana-content/datasources-config
  for i in * ; do
    grep -qw "    tlsAuthWithCACert: true" $i
    ADD_CERTS_YN_LC=$?
    grep -qw "    tlsAuthWithCACert: True" $i
    ADD_CERTS_YN_UC=$?
    if [ "$ADD_CERTS_YN_LC" = "0" ] || [ "$ADD_CERTS_YN_UC" = "0" ]; then
      cat $i | grep -v "json object of data that will be encrypted" | grep -v secureJsonData > /var/lib/plutono/provisioning/datasources/$i
      echo "  # <string> json object of data that will be encrypted." >> /var/lib/plutono/provisioning/datasources/$i
      echo "  secureJsonData:" >> /var/lib/plutono/provisioning/datasources/$i
      if [ -f /grafana-secrets/cacert.crt ]; then
        echo '    tlsCACert: |' >> /var/lib/plutono/provisioning/datasources/$i
        cat /grafana-secrets/cacert.crt | sed 's/^/      /' >> /var/lib/plutono/provisioning/datasources/$i
      fi
      if [ -f /grafana-secrets/sso.crt ]; then
        echo '    tlsClientCert: |' >> /var/lib/plutono/provisioning/datasources/$i
        cat /grafana-secrets/sso.crt | sed 's/^/      /' >> /var/lib/plutono/provisioning/datasources/$i
      fi
      if [ -f /grafana-secrets/sso.key ]; then
        echo '    tlsClientKey: |' >> /var/lib/plutono/provisioning/datasources/$i
        cat /grafana-secrets/sso.key | sed 's/^/      /' >> /var/lib/plutono/provisioning/datasources/$i
      fi
    else
      cp -a $i /var/lib/plutono/provisioning/datasources
    fi
  done
  sed -i 's,__ELK_PASSWORD__,{{.Values.authentication.elk_password}},g' /var/lib/plutono/provisioning/datasources/*
  sed -i 's,__METISDB_PASSWORD__,{{.Values.authentication.metisdb_password}},g' /var/lib/plutono/provisioning/datasources/*
  sed -i 's,__OPENSEARCH_PASSWORD__,{{.Values.authentication.opensearch_password}},g' /var/lib/plutono/provisioning/datasources/*
  sed -i 's,__ALERTMANAGER_PASSWORD__,{{.Values.alertmanager.password}},g' /var/lib/plutono/provisioning/datasources/*
  sed -i 's,__PROMETHEUS_REGION__,{{.Values.global.region}},g' /var/lib/plutono/provisioning/datasources/*

  # strange log config to get no file logging according to https://github.com/grafana/grafana/issues/5018
  cd /usr/share/plutono
  exec /usr/share/plutono/bin/plutono-server -config /var/lib/plutono/etc/plutono.ini --homepath /usr/share/plutono cfg:default.log.mode=console
}

process_config

start_application
