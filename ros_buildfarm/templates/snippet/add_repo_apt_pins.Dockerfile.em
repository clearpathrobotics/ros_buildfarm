@{
_repo_apt_pins = {}
for host_and_priority in repo_apt_pins:
    assert host_and_priority.count(':') == 1
    host, priority = host_and_priority.split(':')
    _repo_apt_pins[host] = priority
}
@[for host, priority in _repo_apt_pins.items()]@
RUN echo "Package: *\nPin: origin @(host)\nPin-Priority: @(priority)\n" | tee -a /etc/apt/preferences.d/00-buildfarm
@[end for]@
