load("//defs:package_defs.bzl", "ebuild_package")

# Pre-generate en_US.UTF-8 locale for the live system
# KDE and GUI applications require UTF-8 locale
ebuild_package(
    name = "glibc-locale",
    source = "//packages/linux/core:glibc-src",
    version = "2.41",
    category = "core",
    slot = "0",
    description = "Pre-generated en_US.UTF-8 locale data",
    
    src_prepare = "true",
    src_configure = "true",
    src_compile = "true",
    
    src_install = """
# Create locale directory
mkdir -p "$DESTDIR/usr/lib/locale"

# Generate en_US.UTF-8 locale
localedef -i en_US -f UTF-8 "$DESTDIR/usr/lib/locale/en_US.UTF-8" --no-archive

echo "Generated en_US.UTF-8 locale"
""",
    
    depend = ["//packages/linux/core:glibc"],
    visibility = ["PUBLIC"],
)
