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
    {%- if job_details.get('hours') is not none %}
    - hours: {{ job_details.hours }}
    {%- endif %}
    {%- if job_details.get('minutes') is not none %}
    - minutes: {{ job_details.minutes }}
    {%- endif %}
    {%- if job_details.get('seconds') is not none %}
    - seconds: {{ job_details.seconds }}
    {%- endif %}
    {%- if job_details.get('cron') is not none %}
    - cron: {{ job_details.cron }}
    {%- endif %}
    {%- if job_details.get('splay') is not none %}
    - splay: {{ job_details.splay }}
    {%- endif %}
    {%- if job_details.get('job_args') is not none %}
    - job_args: {{ job_details.job_args }}
    {%- endif %}
    {%- if job_details.get('on_start') is not none %}
    - on_start: {{ job_details.on_start }}
    {%- endif %}
    {%- if job_details.get('return_job') is not none %}
    - return_job: {{ job_details.return_job }}
    {%- endif %}
{%- endfor %}
