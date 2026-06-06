{{- define "corda-bootstrap.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "corda-bootstrap.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "corda-bootstrap.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "corda-bootstrap.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "corda-bootstrap.labels" -}}
helm.sh/chart: {{ include "corda-bootstrap.chart" . }}
{{ include "corda-bootstrap.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: corda-network
{{- end -}}

{{- define "corda-bootstrap.selectorLabels" -}}
app.kubernetes.io/name: {{ include "corda-bootstrap.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "corda-bootstrap.serviceAccountName" -}}
{{- printf "%s-bootstrapper" (include "corda-bootstrap.fullname" .) -}}
{{- end -}}

{{- define "corda-bootstrap.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}
