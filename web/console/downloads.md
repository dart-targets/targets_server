## Downloads

### Windows and OS X Packages

- [Windows Package with the Eclipse Compiler for Java][win-ecj]
- [Windows Package][win]
- [OS X Package with the Eclipse Compiler for Java][osx-ecj]
- [OS X Package][osx]
- [Multiplatform Package with the Eclipse Compiler for Java][multi-ecj] - **Recommended**
- [Multiplatform Package][multi]

Pick one of the Windows or OS X packages if you only plan to use Targets on that platform. Pick a multiplatform package if you plan to use Targets on both Windows and OS X. If you plan to use Targets for testing code written in Java but do not have the JDK installed, download a package with the Eclipse Compiler for Java. If you already have the JDK installed or you don't plan to use Targets for testing code written in Java, download the standard package.

Extract the package you choose into a directory on your computer or a flash drive. Files will be saved to and loaded from the directory where `Targets Console.exe` (for Windows) or `Targets Console.app` (for OS X) is located. If you plan on using Targets on both platforms, make sure the two application files are in the same directory.

### Linux/Manual Installation

If you don't have the Dart SDK installed, first do so by following the instructions [here](https://www.dartlang.org/tools/download.html). Once the Dart SDK is installed on your path you can install the Targets client with `pub global activate targets \>0.7.10` and then open the console by running `targets console`. Files will be saved to and loaded from the directory where you run the latter command from.

### Licenses

The Targets client itself is licensed under the [3-clause BSD license][bsd-3]. Its source is available on [GitHub][targets_source].

The Dart SDK, which is bundled in all of the Windows and OS X packages above, is also released under the 3-clause BSD license.

The Eclipse Compiler for Java, which is bundled in some of the packages above, is released under the [Eclipse Public License][epl].

[win-ecj]: https://jackthakar.com/targets-downloads/Targets%20Console%20Windows%20%28with%20ECJ%29.zip
[win]: https://jackthakar.com/targets-downloads/Targets%20Console%20Windows.zip
[osx-ecj]: https://jackthakar.com/targets-downloads/Targets%20Console%20OS%20X%20%28with%20ECJ%29.zip
[osx]: https://jackthakar.com/targets-downloads/Targets%20Console%20OS%20X.zip
[multi-ecj]: https://jackthakar.com/targets-downloads/Targets%20Console%20Multiplatform%20%28with%20ECJ%29.zip
[multi]: https://jackthakar.com/targets-downloads/Targets%20Console%20Multiplatform.zip

[bsd-3]: https://en.wikipedia.org/wiki/BSD_licenses#3-clause_license_.28.22Revised_BSD_License.22.2C_.22New_BSD_License.22.2C_or_.22Modified_BSD_License.22.29 
[epl]: https://en.wikipedia.org/wiki/Eclipse_Public_License

[targets_source]: https://github.com/dart-targets/targets