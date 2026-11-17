{{- define "svc.image" -}}
{{- $g := (.Values.global | default dict).image | default dict -}}
{{- $reg := required "set global.image.registry to your ECR URL (<account>.dkr.ecr.<region>.amazonaws.com)" $g.registry -}}
{{ $reg }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default $g.tag | default "v1" }}
{{- end -}}
{{- define "svc.pullPolicy" -}}
{{ ((.Values.global | default dict).image | default dict).pullPolicy | default "IfNotPresent" }}
{{- end -}}
