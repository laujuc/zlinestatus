zig_command := env_var_or_default("ZIG", "zvm run 0.15.2")
default_prefix := env_var_or_default("PREFIX", "/usr/local")

default:
    @just --list

build:
    @{{ zig_command }} build

test:
    @{{ zig_command }} build test

install prefix=default_prefix:
    @{{ zig_command }} build -p "{{ prefix }}"
    install -Dm755 scripts/battery "{{ prefix }}/share/zlinestatus/scripts/battery"
    install -Dm755 scripts/brightness "{{ prefix }}/share/zlinestatus/scripts/brightness"
    install -Dm755 scripts/zlinestatus-instance "{{ prefix }}/share/zlinestatus/scripts/zlinestatus-instance"
    install -Dm755 scripts/volume "{{ prefix }}/share/zlinestatus/scripts/volume"
    install -Dm755 scripts/wifi "{{ prefix }}/share/zlinestatus/scripts/wifi"
    sed "s|@prefix@|{{ prefix }}|g" s6/zlinestatus/run.in | install -Dm755 /dev/stdin "{{ prefix }}/share/zlinestatus/s6/zlinestatus/run"
    install -Dm755 s6/zlinestatus/log/run "{{ prefix }}/share/zlinestatus/s6/zlinestatus/log/run"
    install -Dm644 s6/zlinestatus/env/TYPE "{{ prefix }}/share/zlinestatus/s6/zlinestatus/env/TYPE"
    install -Dm644 s6/zlinestatus/env/WAIT "{{ prefix }}/share/zlinestatus/s6/zlinestatus/env/WAIT"
    sed "s|@prefix@|{{ prefix }}|g" s6/zlinestatus/env/ZLINESTATUS.in | install -Dm644 /dev/stdin "{{ prefix }}/share/zlinestatus/s6/zlinestatus/env/ZLINESTATUS"
    sed "s|@prefix@|{{ prefix }}|g" s6/zlinestatus/env/ZSENDVALUE.in | install -Dm644 /dev/stdin "{{ prefix }}/share/zlinestatus/s6/zlinestatus/env/ZSENDVALUE"
    sed "s|@prefix@|{{ prefix }}|g" systemd/zlinestatus@.service.in | install -Dm644 /dev/stdin "{{ prefix }}/lib/systemd/user/zlinestatus@.service"

clean:
    rm -rf zig-out .zig-cache .zig-cache-local
