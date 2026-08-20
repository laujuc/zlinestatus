zig_command := env_var_or_default("ZIG", "zvm run 0.15.2")

default:
    @just --list

build:
    {{ zig_command }} build

test:
    {{ zig_command }} build test

install prefix="/usr/local":
    {{ zig_command }} build -p "{{ prefix }}"
    install -Dm755 scripts/battery "{{ prefix }}/share/zlinestatus/scripts/battery"
    install -Dm755 scripts/brightness "{{ prefix }}/share/zlinestatus/scripts/brightness"
    install -Dm755 scripts/volume "{{ prefix }}/share/zlinestatus/scripts/volume"
    install -Dm755 scripts/wifi "{{ prefix }}/share/zlinestatus/scripts/wifi"
    install -Dm755 scripts/s6/battery/run "{{ prefix }}/share/zlinestatus/scripts/s6/battery/run"
    sed "s|@prefix@|{{ prefix }}|g" systemd/zlinestatus@.service.in | install -Dm644 /dev/stdin "{{ prefix }}/lib/systemd/user/zlinestatus@.service"
    sed "s|@prefix@|{{ prefix }}|g" systemd/zlinestatus-battery.service.in | install -Dm644 /dev/stdin "{{ prefix }}/lib/systemd/user/zlinestatus-battery.service"
    install -d "{{ prefix }}/share/zlinestatus/cfg"
    if [ ! -e "{{ prefix }}/share/zlinestatus/cfg/WAIT" ]; then printf '5\n' > "{{ prefix }}/share/zlinestatus/cfg/WAIT"; fi

clean:
    rm -rf zig-out .zig-cache .zig-cache-local
