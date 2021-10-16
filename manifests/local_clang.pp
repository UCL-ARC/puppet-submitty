class local_clang {

  $clangdir =  join([lookup('submitty')['install'], "clang-llvm"], '/')
  $clangsrc = join([$clangdir, 'src'], '/')
  $clangbuild = join([$clangdir, 'build'], '/')
  $clanginstall = join([$clangdir, 'install'], '/')

  $clang_dirs = [$clangdir, $clangsrc, $clangbuild, $clanginstall]
  file {$clang_dirs.map | $item | {$item}:
    ensure => directory,
  }

  # NOTE It takes for ever an then doesn't work!
  #      there's a problem finding the tags.
  # vcsrepo { "${clangsrc}/source":
  #   ensure   => present,
  #   provider => git,
  #   source   =>  "https://github.com/llvm/llvm-project",
  #   revision => "llvmorg-7.1.0",
  #   depth    => 1,
  #   require  => File[$clangsrc],
  # }

  # tar striping directories:
  archive { "${clangsrc}/source/llvmorg-7.1.0.tar.gz":
    ensure          => present,
    source          => "https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-7.1.0.tar.gz",
    extract         => true,
    extract_command => 'tar xfz %s --strip-components=1',
    extract_path    => "${clangsrc}/source/",
    cleanup         => true,
    creates         => "${clangsrc}/source/llvm",
  }



  File {"${clangsrc}/compile.sh":
    ensure => file,
    content => "
cp -R ${clangsrc}/source/llvm ${clangsrc}/llvm
cp -R ${clangsrc}/source/clang ${clangsrc}/llvm/tools
cp -R ${clangsrc}/source/clang-tools-extra ${clangsrc}/llvm/tools/clang/tools/
mv ${clangsrc}/llvm/tools/clang/tools/clang-tools-extra ${clangsrc}/llvm/tools/clang/tools/extra
cd ${clangbuild}
cmake -G Ninja ../src/llvm -DCMAKE_INSTALL_PREFIX=${clanginstall} -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++
    ",
    require => Archive["${clangsrc}/source/llvmorg-7.1.0.tar.gz"]
    #Vcsrepo["${clangsrc}/source"]
    }


  exec { "set-clang":
    path    => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    cwd => $clangsrc,
    command => "bash compile.sh",
    creates => "${clangbuild}/.ninja",
    onlyif => "test ! -f ${clangbuild}/build.ninja",
    require => [Archive["${clangsrc}/source/llvmorg-7.1.0.tar.gz"],
                #Vcsrepo["${clangsrc}/source"],
                File["${clangbuild}"],
                File["${clanginstall}"],
               ],
  }

  file_line { 'astmatcher':
    path => "${clangsrc}/llvm/tools/clang/tools/extra/CMakeLists.txt",
    line => 'add_subdirectory(ASTMatcher)',
    require => Exec["set-clang"],
  }
  file_line { 'uniontool':
    path => "${clangsrc}/llvm/tools/clang/tools/extra/CMakeLists.txt",
    line => 'add_subdirectory(UnionTool)',
    require => Exec["set-clang"],
  }


}
