schedule:
  highstate_job:
    function: state.highstate
    minutes: 30
    splay: 10
    enabled: True
    maxrunning: 1
    on_start: False
    return_job: True
