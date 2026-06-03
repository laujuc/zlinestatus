default:
    @just --list

build:
    zig build

test:
    zig build test

install prefix="/usr/local":
    zig build -p "{{prefix}}"
    install -Dm755 scripts/battery "{{prefix}}/share/zlinestatus/scripts/battery"
    install -Dm755 scripts/brightness "{{prefix}}/share/zlinestatus/scripts/brightness"
    install -Dm755 scripts/volume "{{prefix}}/share/zlinestatus/scripts/volume"
    install -Dm755 scripts/wifi "{{prefix}}/share/zlinestatus/scripts/wifi"
    install -Dm755 scripts/s6/battery/run "{{prefix}}/share/zlinestatus/scripts/s6/battery/run"
    if [ ! -e "{{prefix}}/share/zlinestatus/cfg/WAIT" ]; then printf '5\n' > "{{prefix}}/share/zlinestatus/cfg/WAIT"; fi

clean:
    rm -rf zig-out .zig-cache .zig-cache-local
