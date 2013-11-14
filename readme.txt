# this host is a crash & burn environment.

# I have configured Chinese fonts on this host to
# use a perl application I wrote to assist with 
# learning Chinese.

# Any problems and I'll remove it.

# Changes made:

yum install fonts-chinese.noarch
yum install vim-enhanced.x86_64

# lines were added to /root/.vimrc:

set enc=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf8,prc
set guifont=Monaco:h11
set guifontwide=NSimsun:h12

# added some macros to .vimrc

# In putty go to Window -> Translation  and change

from:
ISO-8859-1:1998 (Latin-1, West Europe) to

to:
UTF-8
