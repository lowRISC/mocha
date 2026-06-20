# Root filesystem

The `root` subdirectory consists of extra static files, such as init scripts, which will be added to the built root filesystem image. `root` represents `/` in the final filesystem image. The file tree is copied into the resulting root filesystem tree by `util/make_rootfs.py`.
