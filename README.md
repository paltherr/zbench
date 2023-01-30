# zbench: Zsh code benchmarking

`zbench` allows to benchmark Zsh code. It runs the command to
benchmark in increasingly larger loops and prints timing stats for
each loop.

```console
user@host:~$ zbench 'echo ${PWD/#$HOME/"~"}'
CPU/Clk:  743.000/ 1193.000 µs/run (  0.001/  0.001 s) 63.7% Sys, Runs: 1
CPU/Clk:   65.000/   98.231 µs/run (  0.001/  0.001 s) 61.9% Sys, Runs: 13
CPU/Clk:    8.915/   10.948 µs/run (  0.001/  0.002 s) 43.5% Sys, Runs: 153
CPU/Clk:    4.905/    5.149 µs/run (  0.005/  0.006 s) 28.2% Sys, Runs: 1121
CPU/Clk:    4.539/    4.705 µs/run (  0.020/  0.021 s) 25.7% Sys, Runs: 4484
CPU/Clk:    4.495/    4.560 µs/run (  0.081/  0.082 s) 24.7% Sys, Runs: 17936
CPU/Clk:    4.948/    5.518 µs/run (  0.355/  0.396 s) 24.1% Sys, Runs: 71744
CPU/Clk:    4.448/    4.481 µs/run (  1.277/  1.286 s) 24.1% Sys, Runs: 286976
CPU/Clk:    4.450/    4.487 µs/run ( 10.004/ 10.088 s) 24.2% Sys, Runs: 2248057
```

`zbench` is best suited to benchmark Zsh code but it can also be used
to benchmark command line utilities.

```console
user@host:~$ zbench 'sed -es:^$HOME:~: <<< $PWD'
CPU/Clk: 3005.000/ 3797.000 µs/run (  0.003/  0.004 s) 66.4% Sys, Runs: 1
CPU/Clk: 2575.250/ 3095.250 µs/run (  0.010/  0.012 s) 67.2% Sys, Runs: 4
CPU/Clk: 2531.062/ 2922.125 µs/run (  0.040/  0.047 s) 66.2% Sys, Runs: 16
CPU/Clk: 2419.297/ 2818.609 µs/run (  0.155/  0.180 s) 66.1% Sys, Runs: 64
CPU/Clk: 2411.957/ 2789.188 µs/run (  0.617/  0.714 s) 66.2% Sys, Runs: 256
CPU/Clk: 2563.991/ 3195.077 µs/run (  2.626/  3.272 s) 66.9% Sys, Runs: 1024
CPU/Clk: 2441.736/ 3039.279 µs/run (  9.523/ 11.853 s) 66.3% Sys, Runs: 3900
```

## Installation

### Homebrew

```sh
brew install paltherr/zsh/zbench
```

### Manual

```sh
cd /usr/local/opt
git clone https://github.com/paltherr/zbench.git
cd /usr/local/bin
ln -s ../opt/zbench/src/bin/zbench.zsh
cd /usr/local/share/zsh/site-functions
ln -s ../../../opt/zbench/src/functions/zbench
```


## Usage

`zbench` can be invoked as a standalone command (also from other
shells than Zsh). However, the preferred way is to use it as a Zsh
function. It has the benefit that the benchmarked command can use
functions and variables defined in the calling script/shell.

To use `zbench` as a function, first source `zbench.zsh`, which
defines `zbench` as an autoloaded function. Then `zbench` can be
invoked with a command that references functions and/or variables
defined in the current script/shell.

```zsh
. zbench.zsh

my-fun() { echo "Hello $1!" }
my_var="World"

zbench -d 'my-fun $my_var'
```

For more details, see the [`zbench`
documentation](src/functions/zbench).
