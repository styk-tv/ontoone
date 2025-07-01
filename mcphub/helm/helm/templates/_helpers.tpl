{{- define "mcphub.name" -}}
mcphub
{{- end -}}

{{- define "mcphub.fullname" -}}
{{- printf "%s" (include "mcphub.name" .) -}}
{{- end -}}
