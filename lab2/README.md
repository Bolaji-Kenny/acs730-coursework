# Lab 2 — Deploying a Web App with systemd

`systemctl start` runs the service immediately for the current boot, while
`systemctl enable` creates the symlink that makes systemd start the service
automatically on every future boot — you need both to have it running now
and to have it survive a reboot.


