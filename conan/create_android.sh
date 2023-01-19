archs=(armv8 armv7 x86 x86_64)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

for arch in "${archs[@]}"; do
    conan install "$SCRIPT_DIR" \
    -s arch="$arch" \
    -b missing \
    -b dico \
    -o *:shared=True \
    -pr:h="$SCRIPT_DIR/profile_android" \
    -pr:b=default
done