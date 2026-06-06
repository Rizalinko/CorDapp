{{/* Common naming + label helpers */}}

{{- define "corda-node.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "corda-node.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "corda-node.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "corda-node.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "corda-node.labels" -}}
helm.sh/chart: {{ include "corda-node.chart" . }}
{{ include "corda-node.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: corda-network
app.acmecorp.io/corda-role: {{ .Values.role }}
{{- end -}}

{{- define "corda-node.selectorLabels" -}}
app.kubernetes.io/name: {{ include "corda-node.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "corda-node.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "corda-node.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Image reference: repo:tag, defaulting tag to appVersion */}}
{{- define "corda-node.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* The Secret name holding node passwords (existing or chart-created) */}}
{{- define "corda-node.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "corda-node.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Fail fast on required values */}}
{{- define "corda-node.validate" -}}
{{- if not .Values.legalName -}}
{{- fail "legalName is required (e.g. 'O=Node1, L=London, C=GB')" -}}
{{- end -}}
{{- if and (not .Values.devMode) (not .Values.secrets.existingSecret) (not .Values.secrets.create) -}}
{{- fail "production (devMode=false) requires secrets.existingSecret or secrets.create=true" -}}
{{- end -}}
{{- if and (eq .Values.db.type "postgresql") (not .Values.db.host) -}}
{{- fail "db.host is required when db.type=postgresql" -}}
{{- end -}}
{{- end -}}
