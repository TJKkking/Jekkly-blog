---
layout: post
title: "💻【Jekyll】使用Jekyll搭建个人博客（一）"
categories: tutorial
author: "ooTao"
typora-root-url: ..
---


## 前言

前几天逛Github发现了一个大佬的博客[imageslr.com](imageslr.com)，一下就被简洁的外观和丰富的内容震撼到了，于是决定追随大佬的脚步，先从拥有简洁优美的博客开始。通过参考大佬的博客确定了自己的方案，中间也走了不少弯路，简单写个博客记录一下。

## 方案选择

[Jekyll](http://jekyllcn.com/)是一个简洁的静态网站生成工具，我们可以通过它把Markdown格式的内容生成静态的HTML页面，不需要数据库支持，只需要具备一些前端的基本知识（HTML, CSS）就可以高度定制属于自己的功能。

博客框架确定以后需要考虑的问题是把博客放在哪。通常做法是将博客部署至[Github pages](https://pages.github.com/)，这是Github用于部署静态页面的功能，没有数量限制，每个repository都能配置，使用也非常简单，内容直接取自仓库代码，只需要简单的配置即可，最最重要的是，免费不要钱啊:sob: 简直是业界良心。

但是为了让购买的服务器能够最大限度的发光发热，我决定将它部署在自己的服务器上，毕竟钱不能白花。接下来要准备的还要域名，备案以及SSL证书证书等等。

最后要考虑问题是博客的自动部署，由于Jekyll生成的是静态页面，也就是说每一次添加新内容都需要重新构建网站。我们当然不可能每次写新文章完了还要上服务器手动敲命令行构建，这样的作法too young。这里选择[Jenkins](https://www.jenkins.io/)作为网站的CI(Continuous integration)工具。

## 本地环境搭建

### 安装Ruby

我的本地操作系统是Windows10(x86-64)，在[Downloads (rubyinstaller.org)](https://rubyinstaller.org/downloads/)下载对应版本的Installer，选择安装路径后等待安装完成就可以了，插件就勾选默认的那几个，环境变量啥的都给你配置好了，非常方便。如果勾选了安装MSYS2，会弹出一个命令行窗口，一路ENTER就OK。安装Ruby同时会为你安装[Gem](https://guides.rubygems.org/)，官网介绍gem：The software package is called a “gem” which contains a packaged Ruby application or library.

<img src="/media/1.JPG" alt="1" style="zoom:80%;" />

命令行执行`ruby -v`和`gem -v`查看是否安装成功。

```shell
C:\Users\asus-pc> ruby -v
ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [x64-mingw-ucrt]
C:\Users\asus-pc> gem -v
Active code page: 65001
3.3.7
```

### 安装Jekyll

Jekyll需要的环境已经准备好，接下来只需要执行`gem install jekyll`进行安装。

等待安装完成后执行`jekyll -v`检查是否成功安装。

```shell
C:\Users\asus-pc> jekyll -v
Active code page: 65001
jekyll 4.2.2
```

## 本地博客搭建

### 选择主题

Jekyll拥有非常多的主题，可以在[Jekyll Themes](http://jekyllthemes.org/)这个网站选择自己喜欢的主题下载，也可以从[[jekyll-theme · GitHub Topics](https://github.com/topics/jekyll-theme)直接克隆源代码，本质上是一样的。我选择的主题是[huangyz0918/moving](https://github.com/huangyz0918/moving)。一个透露着王者气息的主题，除了字就没别的。

![banner](/media/banner.jpg)

介绍一下几个文件目录：

- `_includes`包含网页的几个组成部分的HTML文件，例如header、footer等；
- `layouts`包含网页几个主界面的HTML文件，由`_includes`下的文件组合而成，是生成页面的母版；
- `_posts`目录下以.md格式存放我们写的文章；
- `_sass`里是一些样式文件；
- `_site`目录下就是生的静态网页文件，每次重新构建都会删除这个目录并重新创建。
- `_assets`包含辅助资源、css文件以及图片等。

### 本地启动

如果直接运行 `jekyll serve`会报错 `Bundler::GemNotFound`，所以我们选择先安装bundle。bundle是一个gem包的版本管理工具。

```
gem install bundle
```

安装完成后我们需要安装和更新Jekyll需要的gem，先进入到项目目录，将gemfile的**source "https://rubygems.org**"*改为***source ‘https://gems.ruby-china.com’**， 再运行 `bundle install`。

```shell
bundle install
```

bundle通过读取Gemfile得知项目所需的gem包，安装没有的包更新旧的包。

安装完成在项目根目录下运行 `bundle exec jekyll serve`就能在本地启动jekyll服务。

```shell
D:\moving> bundle exec jekyll serve
Active code page: 65001
Active code page: 65001
Configuration file: D:/moving/_config.yml
            Source: D:/moving
       Destination: D:/moving/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
       Jekyll Feed: Generating feed for posts
                    done in 2.334 seconds.
 Auto-regeneration: enabled for 'D:/moving'
    Server address: http://127.0.0.1:4000
  Server running... press ctrl-c to stop.
```

浏览器访问 [http://127.0.0.1:4000](http://127.0.0.1:4000)就能看到网站初始的样子了。

<img src="/media/3.JPG" alt="3" style="zoom: 50%;" />

在我们修改了配置文件后想要让其生效得先删除原来的文件，运行 `bundle exec jekyll clean`清除文件。

```shell
D:\moving> bundle exec jekyll clean
Active code page: 65001
Active code page: 65001
Configuration file: D:/moving/_config.yml
           Cleaner: Removing D:/moving/_site...
           Cleaner: Nothing to do for D:/moving/.jekyll-metadata.
           Cleaner: Removing D:/moving/.jekyll-cache...
           Cleaner: Nothing to do for .sass-cache.
```

可以看到_site文件见已经被删除。运行 `bundle exec jekyll build`重新构建。

```shell
D:\moving> bundle exec jekyll build
Active code page: 65001
Active code page: 65001
Configuration file: D:/moving/_config.yml
            Source: D:/moving
       Destination: D:/moving/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
       Jekyll Feed: Generating feed for posts
                    done in 0.957 seconds.
 Auto-regeneration: disabled. Use --watch to enable.
```

然后再运行 `bundle exec jekyll serve`即可预览。

建议先在本地将博客调试成你想要的样子，方便后续部署到服务器上。

再次鸣谢imageslr大佬。