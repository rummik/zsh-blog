Installation
============
```sh
mkdir -p ~ZSH_CUSTOM/plugins
cd ~ZSH_CUSTOM/plugins
git clone git://github.com/rummik/zsh-blog.git blog
cd blog
git submodule update --init
```

Optionally edit your `~/.zshrc` manually to load `blog`, or with:
```sh
sed -i 's/^plugins=(/plugins=(blog /' ~/.zshrc
```
