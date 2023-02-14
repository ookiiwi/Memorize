SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ABIS=(arm64-v8a x86_64) #armeabi-v7a x86)
NDK=$( find $HOME/Android/Sdk/ndk -maxdepth 1 -type d | sort -V | tail -1 )
PLATFORM=android-26

for ABI in "${ABIS[@]}"; do
    cmake \
    -H"$SCRIPT_DIR/dico" \
    -B"build/$ABI" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="$PLATFORM" \
    -DANDROID_NDK="$NDK" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DBUILD_SHARED_LIBS=ON \
    -G Ninja

    cmake --build "build/$ABI"

    mkdir -p "$SCRIPT_DIR/../android/app/src/main/jniLibs/$ABI" &&
    cp $SCRIPT_DIR/build/$ABI/libdico.so "$_"
done