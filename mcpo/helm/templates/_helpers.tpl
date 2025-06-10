{{- define "mcpo.name" -}}
mcpo
{{- end -}}

{{- define "mcpo.fullname" -}}
{{- printf "%s" (include "mcpo.name" .) -}}
{{- end -}}
