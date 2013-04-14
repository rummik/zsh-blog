Installation
============
```sh
git clone git://github.com/rummik/zsh-blog.git ~/.zblog
mkdir -p ~ZSH_CUSTOM/plugins
ln -s ~/.zblog/ ~ZSH_CUSTOM/plugins/blog
```

Optionally edit your `~/.zshrc` manually to load `blog`, or with:
```sh
sed -i 's/^plugins=(/plugins=(blog /' ~/.zshrc
```
