export CONAN_USER_HOME=/media/HDD_1To/Documents/Projects/memorize/conan/build
export BUILD_SHARED_LIBS=ON

archs=(armv8 armv7 x86 x86_64)
abis=(arm64-v8a armeabi-v7a x86 x86_64)

for i in "${!archs[@]}"; do
    conan create /media/HDD_1To/Documents/Projects/slob4c \
    -s arch="${archs[i]}" \
    -pr:h=profile_android \
    -pr:b=default \
    -b missing \
    -b slob \
    -tf=None \
    -o *:shared=True \
    -r conancenter
done

lib_roots=`echo build/.conan/data/*/*/_/_/build/*`

for dir in $lib_roots; do
    arch=`grep -m 1 "arch=*" "$dir/conaninfo.txt" | sed -e 's/\s*arch=//g'`
    
    for i in "${!archs[@]}"; do
        if [[ "${archs[i]}" = "$arch" ]]; then
            mkdir -p ../android/app/src/main/jniLibs/"${abis[i]}" &&
            cp $dir/build/Release/lib*.so "$_" 2> /dev/null
        fi
    done
done