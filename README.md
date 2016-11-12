# KeepRsyncing

Used for uploading large files on an unstable  and slow connection. Files will be deleted from sending computer once transfered.

----

Installation:
```bash
sudo chmod +x KeepRsyncing.sh

sudo ln -s *LOCATION*/KeepRsyncing.sh /usr/local/bin/
```
----

Edit config file with your details.

1. Username
2. Server
3. Upload Location
4. Upload Speed

----

Usage:
```bash
KeepRsyncing File1 File2 File3 File4 ...
```
----

Note: This really only works if you have an sshkey pair set up.
```bash
ssh-keygen -t rsa -b 4096
ssh-copy-id user@123.45.56.78
```

