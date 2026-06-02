# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  stdenv,
  gnumake,
  cmake,
  rsync,
  fetchFromGitHub,
  llvm_cheri,
  pkgsCross,
}: let
  CHERI_FLAGS = "rv64imaczcherihybrid_zcherilevels";
  MABI = "l64pc128";
in rec {
  linux-headers-purecap = stdenv.mkDerivation {
    pname = "linux-headers-purecap";
    version = "6.18";

    src = fetchFromGitHub {
      owner = "CHERI-Alliance";
      repo = "linux";
      rev = "af04d488044fa684760d6480f3623e51b46568ca";
      fetchSubmodules = true;
      hash = "sha256-Gjjs+vV0meFHOAt9i88WMzpFEq8IZ1oXDFVXb7ZuLI8=";
    };

    nativeBuildInputs = [
      gnumake
      rsync
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      make -j$NIX_BUILD_CORES headers_install \
        ARCH=riscv \
        INSTALL_HDR_PATH=$out/usr

      runHook postInstall
    '';

    meta = {
      description = "CHERI RISC-V 64 purecap Linux kernel (codasip-cheri-riscv-6.18)";
      platforms = ["x86_64-linux"];
    };
  };

  muslc-linux-riscv64-purecap = stdenv.mkDerivation {
    pname = "muslc-linux-riscv64-purecap";
    version = "std093";

    src = fetchFromGitHub {
      owner = "CHERI-Alliance";
      repo = "musl";
      rev = "12d15cddabcfb3f4f0612730f7147e7cf8c5579f";
      fetchSubmodules = true;
      hash = "sha256-8cEUnBQSsWEUoe5gLR/3jFO3KwTddJOhDTDnNZgUIXQ=";
    };

    nativeBuildInputs = [
      gnumake
      llvm_cheri
    ];

    dontConfigure = false;

    configurePhase = ''
      runHook preConfigure

      # Dynamically fetch the resource dir
      RESOURCE_DIR=$(${llvm_cheri}/bin/clang -print-resource-dir)

      ./configure \
        --prefix= \
        --disable-shared \
        CC="clang \
          -target riscv64-linux-musl \
          -march=${CHERI_FLAGS} \
          -mabi=${MABI} \
          -mno-relax \
          -Xclang -target-feature -Xclang +cheri-bounded-vararg \
          -Xclang -target-feature -Xclang +cheri-bounded-memarg-caller \
          -Xclang -target-feature -Xclang +cheri-bounded-memarg-callee \
          -idirafter $RESOURCE_DIR/include"

      runHook postConfigure
    '';

    installPhase = ''
      runHook preInstall

      make install-headers DESTDIR=$out
      make install-libs DESTDIR=$out

      runHook postInstall
    '';

    dontFixup = true;
  };

  compiler-rt-builtins-purecap = stdenv.mkDerivation {
    pname = "compiler-rt-builtins-purecap";
    version = "std093";

    src = llvm_cheri.src;
    sourceRoot = "source/compiler-rt/lib/builtins";

    nativeBuildInputs = [
      cmake
      llvm_cheri
    ];

    llvmCheri = llvm_cheri;
    linuxHeadersPurecap = linux-headers-purecap;

    preConfigure = ''
      substituteAll ${./CrossToolchain.cmake.in} CrossToolchain.cmake
    '';

    configurePhase = ''
      runHook preConfigure

      cmake -S . -B build \
        --toolchain=../CrossToolchain.cmake \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DLLVM_CONFIG_PATH=NOTFOUND \
        -DCMAKE_DISABLE_FIND_PACKAGE_LLVM=true \
        -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=false \
        -DCOMPILER_RT_BAREMETAL_BUILD=false \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=true \
        -DTARGET_TRIPLE="riscv64-linux-musl" \
        -DCMAKE_SYSROOT="${muslc-linux-riscv64-purecap}" \
        -DCOMPILER_RT_DEBUG=true \
        -DCMAKE_C_COMPILER=${llvm_cheri}/bin/clang \
        -DCMAKE_CXX_COMPILER=${llvm_cheri}/bin/clang++ \
        -DCMAKE_ASM_COMPILER=${llvm_cheri}/bin/clang \
        -DCMAKE_C_FLAGS="-march=${CHERI_FLAGS} -mabi=${MABI} -isystem ${linux-headers-purecap}/usr/include" \
        -DCMAKE_CXX_FLAGS="-march=${CHERI_FLAGS} -mabi=${MABI} -isystem ${linux-headers-purecap}/usr/include" \
        -DCMAKE_ASM_FLAGS="-march=${CHERI_FLAGS} -mabi=${MABI} -isystem ${linux-headers-purecap}/usr/include" \
        -DCMAKE_INSTALL_PREFIX="$out"
    '';

    buildPhase = ''
      cmake --build build
    '';

    installPhase = ''
      cmake --build build --target install
      runHook postInstall
    '';

    postInstall = ''
      mkdir -p $out/lib

      ln -fsn $out/lib/linux/libclang_rt.builtins-riscv64.a $out/lib/libclang_rt.builtins-riscv64.a
      ln -fsn $out/lib/linux/libclang_rt.builtins-riscv64.a $out/lib/libgcc.a

      ln -fsn $out/lib/linux/clang_rt.crtbegin-riscv64.o $out/lib/crtbeginT.o
      ln -fsn $out/lib/linux/clang_rt.crtbegin-riscv64.o $out/lib/crtbeginS.o
      ln -fsn $out/lib/linux/clang_rt.crtend-riscv64.o $out/lib/crtend.o
      ln -fsn $out/lib/linux/clang_rt.crtend-riscv64.o $out/lib/crtendS.o
    '';

    dontFixup = true;
  };

  cheriBintools = pkgsCross.riscv64.wrapBintoolsWith {
    bintools = llvm_cheri;
    libc = muslc-linux-riscv64-purecap;
    coreutils = pkgsCross.riscv64.buildPackages.coreutils;
    extraBuildCommands = ''
      for tool in ar as nm objcopy objdump ranlib readelf size strings strip; do
        # Link bare names: llvm-nm -> nm
        if [ -x "$out/bin/$tool" ]; then
          ln -s "$tool" "$out/bin/llvm-$tool"
        fi
      done
    '';
  };

  cheriCC = pkgsCross.riscv64.wrapCCWith {
    cc = llvm_cheri;
    bintools = cheriBintools;
    libc = muslc-linux-riscv64-purecap;
    coreutils = pkgsCross.riscv64.buildPackages.coreutils;
    extraBuildCommands = ''
      echo "-isystem ${linux-headers-purecap}/usr/include" >> $out/nix-support/cc-cflags
      echo "-B${compiler-rt-builtins-purecap}/lib" >> $out/nix-support/cc-cflags
      echo "-L${compiler-rt-builtins-purecap}/lib" >> $out/nix-support/cc-ldflags
    '';
  };

  cheriStdenv = pkgsCross.riscv64.stdenv.override {
    cc = cheriCC;
    allowedRequisites = null;

    targetPlatform =
      stdenv.targetPlatform
      // {
        config = "riscv64-linux-musl";
        libc = "musl";
      };
  };
}
