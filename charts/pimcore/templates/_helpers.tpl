{{/*
Expand the name of the chart.
*/}}
{{- define "pimcore.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pimcore.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pimcore.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pimcore.labels" -}}
helm.sh/chart: {{ include "pimcore.chart" . }}
{{ include "pimcore.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pimcore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pimcore.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pimcore.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pimcore.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "pimcore.initContainers.wait-for-mysql" -}}
- name: wait-for-mysql
  image: divante/mysql-client:1.0.0
  command:
    - sh
    - -c
    - until mysql -u {{ .Values.pimcore.db.username | quote }} -p{{ .Values.pimcore.db.password | quote }} -h {{ .Values.pimcore.db.host | quote }} {{ .Values.pimcore.db.name | quote }} -e "SELECT 1"; do echo wait-for-mysql; sleep 5; done;
{{- end -}}

{{- define "pimcore.initContainers.wait-for-pimcore-installed" -}}
- name: wait-for-pimcore-installed
  image: busybox:latest
  command:
  - "sh"
  - "-c"
  - "until [ -f /var/www/pimcore/var/installed ]; do echo wait-for-pimcore-installed; sleep 5; done;"
  volumeMounts:
  - name: pimcore-data
    mountPath: /var/www
{{- end -}}

{{/*
Create PodTemplateSpec.containers[].volumeMounts from customConfigFiles
*/}}
{{- define "pimcore.customConfigFiles.volumeMounts" -}}
{{- range $name, $config := .Values.pimcore.customConfigFiles }}
{{- if $config.enabled }}
- name: {{ $name }}
  mountPath: /var/www/pimcore/{{ $config.containerPath }}
  subPath: {{ $name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create PodTemplateSpec.volumes from customConfigFiles
*/}}
{{- define "pimcore.customConfigFiles.volumes" -}}
{{- range $name, $config := .Values.pimcore.customConfigFiles }}
{{- if $config.enabled }}
- name: {{ $name }}
  configMap:
    name: {{ template "pimcore.fullname" $ }}-{{ $name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create the name of the PVC to use as Pimcore installation
*/}}
{{- define "pimcore.dataClaimName" -}}
{{- if .Values.pvc.data.existingClaim }}
{{- .Values.pvc.data.existingClaim }}
{{- else }}
{{- include "pimcore.fullname" $ }}-{{ .Values.pvc.data.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the PVC to use for storing Pimcore MySQL backup dumps
*/}}
{{- define "pimcore.mysqlBackupClaimName" -}}
{{- if .Values.pvc.mysqlBackup.existingClaim }}
{{- .Values.pvc.mysqlBackup.existingClaim }}
{{- else }}
{{- include "pimcore.fullname" $ }}-{{ .Values.pvc.mysqlBackup.name }}
{{- end }}
{{- end }}

{{/*
Returns 'true' if some of the pimcore.customConfigFiles is enabled
*/}}
{{- define "pimcore.useCustomConfigFiles" -}}
{{- $allDisabled := true }}
{{- range $key, $value := .Values.pimcore.customConfigFiles }}
  {{- if $value.enabled }}
    {{- $allDisabled = false }}
  {{- end }}
{{- end }}
{{- $someEnabled := not $allDisabled }}
{{- $someEnabled }}
{{- end }}

{{/*
Creates a POSIX shell that iterates over all .Values.customConfigFiles[*].containerPath
for each .Values.customConfigFiles[*].enabled and replaces the file with a note
that the file is managed by ConfigMap
*/}}
{{- define "pimcore.overrideCustomConfigFiles" -}}
{{- range $name, $config := .Values.pimcore.customConfigFiles }}
{{- if $config.enabled }}
echo "This file is managed by a ConfigMap" > /var/www/pimcore/{{ $config.containerPath }}
{{- end }}
{{- end }}
{{- end }}
