# Chinese learning application.

# To run on RHEL:

yum install fonts-chinese.noarch
yum install vim-enhanced.x86_64

# add lines to ~/.vimrc:

set enc=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf8,prc
set guifont=Monaco:h11
set guifontwide=NSimsun:h12

# If using putty go to Window -> Translation  and change

from:
ISO-8859-1:1998 (Latin-1, West Europe) to

to:
UTF-8
