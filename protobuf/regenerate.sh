#!/bin/sh -ex

cd $(dirname $0)

die() {
    echo "$@" >&2
    exit 1
}

protoc_ver=$(protoc --version)
case "$protoc_ver" in
"libprotoc 3"*) ;;
*)
    die "you need to use protobuf 3 to regenerate .rs from .proto"
    ;;
esac

cargo build --manifest-path=../protobuf-codegen/Cargo.toml
cargo build --manifest-path=../protoc-bin-vendored/Cargo.toml --bin protoc-bin-which

PROTOC=$(cargo run --manifest-path=../protoc-bin-vendored/Cargo.toml --bin protoc-bin-which)

where_am_i=$(
    cd ..
    pwd
)

rm -rf tmp-generated
mkdir tmp-generated

case $(uname) in
Linux)
    exe_suffix=""
    ;;
MSYS_NT*)
    exe_suffix=".exe"
    ;;
esac

"$PROTOC" \
    --plugin=protoc-gen-rust="$where_am_i/target/debug/protoc-gen-rust$exe_suffix" \
    --rust_out tmp-generated \
    --rust_opt 'inside_protobuf=true' \
    -I../proto \
    -I../protoc-bin-vendored/include \
    ../protoc-bin-vendored/include/google/protobuf/*.proto \
    ../protoc-bin-vendored/include/google/protobuf/compiler/* \
    ../proto/rustproto.proto \
    ../proto/doctest_pb.proto

find tmp-generated -name '*.rs' | while read -r f; do
    sed -e '
        s^// @@protoc_insertion_point(special_field:.*^#[cfg_attr(serde, serde(skip))]^;
        s^// @@protoc_insertion_point(message:.*^#[cfg_attr(serde, derive(::serde::Serialize, ::serde::Deserialize))]^;
        /@@protoc_insertion_point/ d;
    ' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
done

mv \
    tmp-generated/descriptor.rs \
    tmp-generated/plugin.rs \
    tmp-generated/rustproto.rs \
    tmp-generated/doctest_pb.rs \
    src/
mv tmp-generated/well_known_types_mod.rs src/well_known_types/mod.rs
mv tmp-generated/*.rs src/well_known_types/

# vim: set ts=4 sw=4 et:
