#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

./build-llvm.py \
	--clang-vendor "Razr" \
	--defines "LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3" \
	--incremental \
	--lto thin \
	--projects "clang;lld;polly;compiler-rt" \
	--pgo kernel-defconfig \
	--shallow-clone \
	--targets "ARM;AArch64;X86" 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
	exit 1
}

./build-binutils.py --targets arm aarch64 x86_64

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done
