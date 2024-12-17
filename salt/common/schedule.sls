{% set schedule = salt['pillar.get']('schedule', {}) %}

enable_scheduler:
  module.run:
    - name: schedule.enable

{%- for job_name, job_details in schedule.items() %}
apply_{{ job_name }}:
  schedule.present:
    - name: {{ job_name }}
    - function: {{ job_details.function }}
    - enabled: {{ job_details.enabled }}
    - maxrunning: {{ job_details.maxrunning }}
    {%- if job_details.get('hours') %}
    - hours: {{ job_details.hours }}
    {%- endif %}
    {%- if job_details.get('minutes') %}
    - minutes: {{ job_details.minutes }}
    {%- endif %}
    {%- if job_details.get('seconds') %}
    - seconds: {{ job_details.seconds }}
    {%- endif %}
    {%- if job_details.get('cron') %}
    - cron: {{ job_details.cron }}
    {%- endif %}
    {%- if job_details.get('splay') %}
    - splay: {{ job_details.splay }}
    {%- endif %}
    {%- if job_details.get('job_args') %}
    - job_args: {{ job_details.job_args }}
    {%- endif %}
    {%- if job_details.get('on_start') %}
    - on_start: {{ job_details.on_start }}
    {%- endif %}
    {%- if job_details.get('return_job') %}
    - return_job: {{ job_details.return_job }}
    {%- endif %}
{%- endfor %}