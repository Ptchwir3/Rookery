{{/*
Expand the name of the chart.
*/}}
{{- define "rookery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "rookery.fullname" -}}
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
Common labels
*/}}
{{- define "rookery.labels" -}}
helm.sh/chart: {{ include "rookery.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: rookery
{{- end }}

{{/*
Leader labels
*/}}
{{- define "rookery.leaderLabels" -}}
{{ include "rookery.labels" . }}
app.kubernetes.io/name: {{ include "rookery.fullname" . }}-leader
app.kubernetes.io/component: leader
{{- end }}

{{/*
Worker labels
*/}}
{{- define "rookery.workerLabels" -}}
{{ include "rookery.labels" . }}
app.kubernetes.io/name: {{ include "rookery.fullname" . }}-worker
app.kubernetes.io/component: worker
{{- end }}

{{/*
Model filename - derive from URL if not explicitly set
*/}}
{{- define "rookery.modelFilename" -}}
{{- if .Values.model.filename }}
{{- .Values.model.filename }}
{{- else }}
{{- .Values.model.url | trimSuffix "/" | base }}
{{- end }}
{{- end }}
