# bash-prompt
Customizable bash prompt

```Bash
cmccandless@CMCCANDLESS:~/repos$ cd bash-prompt/
(bash-prompt: master)
cmccandless@CMCCANDLESS:~/repos/bash-prompt$ touch new_file
(bash-prompt: master*)
cmccandless@CMCCANDLESS:~/repos/bash-prompt$ git add new_file
(bash-prompt: master*)
cmccandless@CMCCANDLESS:~/repos/bash-prompt$ git commit -m 'add new_file'
[master 5d0da6f] add new_file
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 new_file
(bash-prompt: master)
cmccandless@CMCCANDLESS:~/repos/bash-prompt$ 
```

## Installation

```Bash
curl -f https://raw.githubusercontent.com/cmccandless/bash-prompt/master/set_prompt.sh > ~/bin/set_prompt.sh
echo "source $HOME/bin/set_prompt.sh" >> $HOME/.bashrc
```
