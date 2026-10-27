{{- define "task-tracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "task-tracker.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "task-tracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "task-tracker.labels" -}}
helm.sh/chart: {{ include "task-tracker.chart" . }}
app.kubernetes.io/name: {{ include "task-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "task-tracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "task-tracker.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
tier: {{ .tier }}
{{- end -}}

{{- define "task-tracker.configMapName" -}}
{{- printf "%s-config" (include "task-tracker.fullname" .) -}}
{{- end -}}

{{- define "task-tracker.credentialsSecretName" -}}
{{- default (printf "%s-credentials" (include "task-tracker.fullname" .)) .Values.credentials.existingSecret -}}
{{- end -}}

{{- define "task-tracker.databaseServiceName" -}}
{{- printf "%s-db" (include "task-tracker.fullname" .) -}}
{{- end -}}

{{- define "task-tracker.backendServiceName" -}}
{{- printf "%s-backend" (include "task-tracker.fullname" .) -}}
{{- end -}}

{{- define "task-tracker.frontendServiceName" -}}
{{- printf "%s-frontend" (include "task-tracker.fullname" .) -}}
{{- end -}}
