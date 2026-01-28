load("//defs:package_defs.bzl", "rootfs")

rootfs(
    name = "installer-rootfs",
    packages = [
        "system//apps:coreutils",
        "core//util-linux:util-linux",
        "core//procps-ng:procps-ng",
        "system//apps/shadow:shadow",
        "core//file:file",
        "core//bash:bash",
        "core//zlib:zlib",
        "core//glibc:glibc",
        "//packages/linux/network:openssl",
        "//packages/linux/network:curl",
        "//packages/linux/network:iproute2",
        "//packages/linux/network:openssh",
        "//packages/linux/editors:vim",
    ],
    visibility = ["PUBLIC"],
)
